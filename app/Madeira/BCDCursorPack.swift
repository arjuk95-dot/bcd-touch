// SPDX-License-Identifier: GPL-3.0-or-later
// Relative cursor packs: deterministic touch ownership, no game-state inference.
import Foundation
import CoreGraphics

final class BCDCursorPack {
    enum Mode: String { case gameplay, equipment, utilities, pointer, paused }
    enum Event: Equatable { case button(String, Bool), motion(Int32, Int32), customize }
    struct Finger {
        var role: String; var action: String?; var start: CGPoint; var last: CGPoint; var began: Double
        var firing = false; var selection: Int?; var moved = false
    }
    var pack: BCDControlPack
    var layout: BCDControlPack.Layout
    var bounds = CGRect.zero; var safe = CGRect.zero
    /// Actual presented Metal surface size, not safe area or the physical screen.
    var viewport = CGSize(width: 960, height: 540)
    var guest = CGSize(width: 960, height: 540)
    private(set) var mode: Mode = .gameplay
    private(set) var fingers: [AnyHashable: Finger] = [:]
    private var holds: [String: Set<AnyHashable>] = [:]
    private var pulses: [(owner: UUID, due: Double)] = []
    private var events: [Event] = []
    private var carry = CGPoint.zero
    private var clock = 0.0
    init(pack: BCDControlPack, pad: Bool) { self.pack=pack; layout=pad ? pack.pad : pack.phone }
    var settings: BCDControlPack.CursorControls { pack.cursorControls! }
    var movement: BCDControlPack.DigitalMovement { pack.digitalMovement! }
    var unit: CGFloat { max(1,min(safe.width,safe.height)) }
    var movementFinger: Finger? { fingers.values.first { $0.role == "move" } }
    var firing: Bool { !(holds["mouse:left"] ?? []).isEmpty && mode == .gameplay }
    var activeOutputs: Set<String> { Set(holds.filter { !$0.value.isEmpty }.keys) }
    func drain() -> [Event] { defer { events.removeAll() }; return events }
    func center(_ c: BCDControlPack.Control) -> CGPoint {
        let frame=c.coordinateSpace == "screen" ? bounds : safe
        return CGPoint(x:frame.minX+CGFloat(c.x)*frame.width,y:frame.minY+CGFloat(c.y)*frame.height)
    }
    func rect(_ r: BCDControlPack.Layout.Rect, screen: Bool = false) -> CGRect {
        let b=screen ? bounds : safe
        return CGRect(x:b.minX+CGFloat(r.x)*b.width,y:b.minY+CGFloat(r.y)*b.height,width:CGFloat(r.width)*b.width,height:CGFloat(r.height)*b.height)
    }
    func hit(_ c: BCDControlPack.Control, _ point: CGPoint) -> Bool {
        hypot(point.x-center(c).x,point.y-center(c).y) <= CGFloat(c.hitRadius)*unit
    }
    private func action(_ id: String) -> BCDControlPack.Action? { pack.actions.first { $0.id == id } }
    private func leaves(_ id: String) -> [String] {
        guard let a=action(id) else { return [] }
        return BCDPackCatalog.keyCodes(a.output)?.map { "key:\($0)" } ?? [a.output]
    }
    private func hold(_ id: String, _ owner: AnyHashable) {
        for output in leaves(id) {
            let first=holds[output,default:[]].isEmpty
            holds[output,default:[]].insert(owner)
            if first { events.append(.button(output,true)) }
        }
    }
    private func release(_ owner: AnyHashable) {
        for key in Array(holds.keys) where holds[key]?.contains(owner) == true {
            holds[key]?.remove(owner)
            if holds[key]?.isEmpty == true { events.append(.button(key,false));holds[key]=nil }
        }
    }
    private func pulse(_ id: String, time: Double) {
        let owner=UUID();hold(id,owner);pulses.append((owner,time+0.08))
    }
    func tick(_ time: Double) {
        clock=time
        for p in pulses where p.due<=time { release(p.owner) }
        pulses.removeAll { $0.due<=time }
    }
    func cancel(resetMode: Bool = true) {
        for output in holds.keys.sorted() { events.append(.button(output,false)) }
        holds.removeAll();pulses.removeAll();fingers.removeAll();carry = .zero
        if resetMode { mode = .gameplay }
    }
    /// Existing moving thumb may continue while the wheel is open. Aiming/fire
    /// fingers are quarantined until lift; closing the wheel never reactivates them.
    private func suspendAim() {
        for id in Array(fingers.keys) where fingers[id]?.role != "move" {
            release(id);fingers[id]?.role="ignore";fingers[id]?.firing=false
        }
        for p in pulses { release(p.owner) };pulses.removeAll();carry = .zero
    }
    func switchMode(_ next: Mode) { cancel(resetMode:false);mode=next }
    func openInventory(time: Double) { switchMode(.pointer);pulse(settings.inventory,time:time) }
    func pause(time: Double) { switchMode(.paused);pulse(settings.pause,time:time) }
    private func pointerMove(_ f: Finger, to p: CGPoint) {
        let gain=CGFloat(pack.aim.sensitivity*(f.firing ? settings.firingMultiplier : 1))
        let vertical=CGFloat(pack.aim.vertical)*(pack.aim.invertY ? -1:1)
        carry.x += (p.x-f.last.x)*gain*guest.width/max(1,viewport.width)
        carry.y += (p.y-f.last.y)*gain*vertical*guest.height/max(1,viewport.height)
        let dx=Int32(max(-30000,min(30000,carry.x))),dy=Int32(max(-30000,min(30000,carry.y)))
        // Preserve fractions; discard any saturated integer excess immediately.
        carry.x-=carry.x.rounded(.towardZero);carry.y-=carry.y.rounded(.towardZero)
        if dx != 0 || dy != 0 { events.append(.motion(dx,dy)) }
    }
    private func moveKeys(_ f: Finger, owner: AnyHashable) {
        let radius=unit*CGFloat(layout.controls.first { $0.role == "move" }?.radius ?? 0.14)
        let x=Double((f.last.x-f.start.x)/max(1,radius)), y=Double((f.start.y-f.last.y)/max(1,radius))
        func on(_ id: String) -> Bool { leaves(id).contains { holds[$0]?.contains(owner) == true } }
        let m=movement
        var desired:[String]=[]
        if x <= -(on(m.left) ? m.deadZone-m.hysteresis:m.deadZone) { desired.append(m.left) }
        if x >= (on(m.right) ? m.deadZone-m.hysteresis:m.deadZone) { desired.append(m.right) }
        if y >= (on(m.up) ? m.flightThreshold-m.hysteresis:m.flightThreshold) { desired.append(m.up) }
        if -y >= (on(m.down) ? m.downThreshold-m.hysteresis:m.downThreshold) { desired.append(m.down) }
        // Atomic desired-set difference avoids chatter and horizontal release when flight changes.
        let outputs=Set(desired.flatMap { leaves($0) })
        for key in Array(holds.keys) where holds[key]?.contains(owner)==true && !outputs.contains(key) {
            holds[key]?.remove(owner)
            if holds[key]?.isEmpty==true { events.append(.button(key,false));holds[key]=nil }
        }
        for id in desired { hold(id,owner) }
    }
    var radialFrame: CGRect {
        let r=min(unit*CGFloat(settings.radialRadius),min(safe.width,safe.height)/2-30)
        let x=max(safe.minX+r+4,min(safe.maxX-r-4,safe.minX+safe.width*CGFloat(settings.radialX)))
        let y=max(safe.minY+r+4,min(safe.maxY-r-68,safe.minY+safe.height*CGFloat(settings.radialY)))
        return CGRect(x:x-r,y:y-r,width:r*2,height:r*2)
    }
    func sector(_ point: CGPoint) -> Int? {
        let r=radialFrame;let dx=point.x-r.midX,dy=point.y-r.midY
        guard hypot(dx,dy)>r.width*0.18 && hypot(dx,dy)<=r.width*0.5 else { return nil }
        let angle=(atan2(dy,dx) + .pi/2 + .pi/8 + 2 * .pi).truncatingRemainder(dividingBy:2 * .pi)
        return Int(angle/(2 * .pi)*8)%8
    }
    var moreFrame: CGRect { let r=radialFrame;return CGRect(x:r.midX-46,y:r.maxY+4,width:92,height:44) }
    /// Explicit utility and pointer controls; these never pretend a key proved a game state.
    var overlayButtons: [(String,String,CGRect)] {
        if mode == .utilities {
            let width=min(safe.width-16,300),height:CGFloat=48
            let x=max(safe.minX+8,min(safe.maxX-width-8,radialFrame.midX-width/2))
            return [("throw","Throw selected item"),("eat","Hold Down / Eat"),("pointer","Pointer mode only"),("customize","Customize controls"),("return","Return to game")].enumerated().map { i,p in (p.0,p.1,CGRect(x:x,y:safe.midY-120+CGFloat(i)*height,width:width,height:height-3)) }
        }
        if mode == .pointer || mode == .paused {
            return [("click","Select / drag"),("secondary","Secondary click"),("close",mode == .pointer ? "Close inventory (Tab)":"Resume (Esc)"),("recover","Gameplay only")].enumerated().map { i,p in
                (p.0,p.1,CGRect(x:safe.maxX-178,y:safe.minY+8+CGFloat(i)*49,width:170,height:44))
            }
        }
        return []
    }
    private func equip(_ index: Int, time: Double) {
        suspendAim();mode = .gameplay
        if pack.radial.indices.contains(index) { pulse(pack.radial[index],time:time) }
    }
    func begin(_ id: AnyHashable, at p: CGPoint, time: Double) {
        tick(time)
        if let hit=overlayButtons.first(where:{$0.2.contains(p)}) {
            switch hit.0 {
            case "click","secondary":
                let a=hit.0=="click" ? settings.primaryClick:settings.secondaryClick
                fingers[id]=Finger(role:"pointerDrag",action:a,start:p,last:p,began:time);hold(a,id)
            case "eat": fingers[id]=Finger(role:"button",action:movement.down,start:p,last:p,began:time);hold(movement.down,id)
            case "throw": suspendAim();pulse(settings.throwAction,time:time);fingers[id]=Finger(role:"ignore",start:p,last:p,began:time)
            case "customize": cancel();events.append(.customize)
            case "pointer": switchMode(.pointer)
            case "close": let a=mode == .pointer ? settings.inventory:settings.pause;switchMode(.gameplay);pulse(a,time:time)
            case "recover","return": switchMode(.gameplay)
            default:break
            }
            return
        }
        if mode == .equipment {
            if moreFrame.contains(p) { suspendAim();mode = .utilities;return }
            if let i=sector(p) { equip(i,time:time) } else { suspendAim();mode = .gameplay }
            fingers[id]=Finger(role:"ignore",start:p,last:p,began:time);return
        }
        if mode == .utilities { fingers[id]=Finger(role:"ignore",start:p,last:p,began:time);return }
        if mode == .pointer || mode == .paused {
            let hasPointer=fingers.values.contains { $0.role=="look" || $0.role=="pointerDrag" }
            fingers[id]=Finger(role:hasPointer ? "ignore":"look",start:p,last:p,began:time);return
        }
        let c=layout.controls.reversed().first { $0.role != "move" && hit($0,p) && action($0.action)?.contexts.contains("onFoot") != false }
        if let c {
            if c.action==settings.inventory { openInventory(time:time);return }
            if c.action==settings.pause { pause(time:time);return }
            if c.role=="radial" { suspendAim();mode = .equipment;fingers[id]=Finger(role:"radial",start:p,last:p,began:time);return }
            var f=Finger(role:c.role,action:c.action,start:p,last:p,began:time)
            if c.action==settings.fire && c.role=="fireAim" {
                if fingers.values.contains(where:{$0.role=="look" || $0.role=="fireAim"}) { f.role="ignore" }
                else { f.firing=true;hold(c.action,id) }
            } else if action(c.action)?.behavior=="hold" { hold(c.action,id) }
            else { pulse(c.action,time:time) }
            fingers[id]=f;return
        }
        let m=layout.movementRect ?? .init(x:0,y:0.3,width:0.4,height:0.7)
        let role: String
        if rect(m,screen:true).contains(p) { role=fingers.values.contains(where:{$0.role=="move"}) ? "ignore":"move" }
        else if rect(layout.aimRect).contains(p), !fingers.values.contains(where:{$0.role=="look" || $0.role=="fireAim"}) { role="look" }
        else { role="ignore" }
        fingers[id]=Finger(role:role,start:p,last:p,began:time)
    }
    func move(_ id: AnyHashable, to p: CGPoint, time: Double) {
        tick(time);guard var f=fingers[id] else { return }
        f.moved = f.moved || hypot(p.x-f.start.x,p.y-f.start.y)>8
        if f.role=="look" || f.role=="fireAim" || f.role=="pointerDrag" {
            pointerMove(f,to:p)
            if mode == .gameplay && f.role=="look", let c=layout.controls.first(where:{$0.action==settings.fire && $0.role=="fireAim"}), hit(c,p) {
                f.role="fireAim";f.action=settings.fire;f.firing=true;hold(settings.fire,id)
            }
        }
        f.last=p
        if f.role=="move" { moveKeys(f,owner:id) }
        if f.role=="radial" { f.selection=sector(p) }
        fingers[id]=f
    }
    func end(_ id: AnyHashable, at p: CGPoint, time: Double, cancelled: Bool) {
        if cancelled {
            if fingers[id]?.role=="radial" { mode = .gameplay }
            fingers[id]=nil;release(id);return
        }
        // Include final delivered position for deliberate fire crossing and radial selection.
        move(id,to:p,time:time)
        guard let f=fingers.removeValue(forKey:id) else { return };release(id)
        if f.role=="radial" {
            if cancelled { mode = .gameplay;return }
            if !f.moved { mode = time-f.began<0.28 ? .equipment:.gameplay;return }
            if let i=sector(p) { equip(i,time:time) } else { mode = .gameplay }
        }
    }
}

#if canImport(UIKit)
import UIKit
@MainActor extension BCDCursorPack {
    func drawOverlay(_ ctx: CGContext) {
        func text(_ s: String, _ p: CGPoint, size: CGFloat = 13) {
            let font=UIFont.systemFont(ofSize:size,weight:.regular)
            let width=(s as NSString).size(withAttributes:[.font:font]).width
            (s as NSString).draw(at:CGPoint(x:p.x-width/2,y:p.y-size/2),withAttributes:[.font:font,.foregroundColor:UIColor.white.withAlphaComponent(0.82)])
        }
        if mode == .equipment {
            let r=radialFrame,center=CGPoint(x:r.midX,y:r.midY),radius=r.width/2,inner=radius*0.36
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.56).cgColor);ctx.fillEllipse(in:r)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor);ctx.setLineWidth(1)
            ctx.strokeEllipse(in:r);ctx.strokeEllipse(in:CGRect(x:center.x-inner,y:center.y-inner,width:inner*2,height:inner*2))
            let selected=fingers.values.first { $0.role=="radial" }?.selection
            for i in 0..<8 {
                let angle=Double(i)*Double.pi/4-Double.pi/2
                let edge=angle-Double.pi/8
                if selected==i {
                    ctx.saveGState();ctx.setFillColor(UIColor.systemTeal.withAlphaComponent(0.28).cgColor)
                    ctx.move(to:center);ctx.addArc(center:center,radius:radius,startAngle:edge,endAngle:edge+Double.pi/4,clockwise:false);ctx.closePath();ctx.fillPath();ctx.restoreGState()
                }
                ctx.move(to:CGPoint(x:center.x+cos(edge)*inner,y:center.y+sin(edge)*inner))
                ctx.addLine(to:CGPoint(x:center.x+cos(edge)*radius,y:center.y+sin(edge)*radius));ctx.strokePath()
                let p=CGPoint(x:center.x+cos(angle)*radius*0.7,y:center.y+sin(angle)*radius*0.7)
                text("\(i+1)",CGPoint(x:p.x,y:p.y-12),size:14)
                if let icon=BCDPackIcons.image(i<4 ? "bcd.wand":"bcd.inventory")?.withTintColor(.white,renderingMode:.alwaysOriginal) {
                    icon.draw(in:CGRect(x:p.x-10,y:p.y,width:20,height:20))
                }
            }
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor);ctx.fillEllipse(in:CGRect(x:center.x-inner+1,y:center.y-inner+1,width:inner*2-2,height:inner*2-2))
            text("Cancel",center)
            ctx.addPath(UIBezierPath(roundedRect:moreFrame,cornerRadius:15).cgPath);ctx.strokePath();text("More",CGPoint(x:moreFrame.midX,y:moreFrame.midY))
            text("Game continues",CGPoint(x:r.midX,y:moreFrame.maxY+11),size:11)
        }
        for (_,label,r) in overlayButtons {
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.65).cgColor);ctx.addPath(UIBezierPath(roundedRect:r,cornerRadius:10).cgPath);ctx.fillPath()
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.55).cgColor);ctx.setLineWidth(1);ctx.addPath(UIBezierPath(roundedRect:r,cornerRadius:10).cgPath);ctx.strokePath()
            text(label,CGPoint(x:r.midX,y:r.midY),size:13)
        }
        if mode == .pointer || mode == .paused {
            text("Explicit pointer mode · use Gameplay only if out of sync",CGPoint(x:safe.midX,y:safe.minY+14),size:11)
        }
    }
}
#endif
