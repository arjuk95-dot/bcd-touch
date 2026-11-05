// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct BCDCursorPackSettings: View {
    @ObservedObject private var store=BCDPackStore.shared
    var pad: Bool
    func edit(_ f:(inout BCDControlPack)->Void) { if var p=store.pack { f(&p);_ = store.saveEdits(p) } }
    func slider(_ title:String,_ value:Double,_ range:ClosedRange<Double>,_ set:@escaping(Double)->Void) -> some View {
        VStack { Text("\(title) \(value,specifier:"%.2f")").font(.caption);Slider(value:Binding(get:{value},set:set),in:range.lowerBound<range.upperBound ? range:0...1).disabled(range.lowerBound==range.upperBound) }
    }
    var body: some View {
        if let p=store.pack,let c=p.cursorControls,let m=p.digitalMovement {
            VStack(spacing:10) {
                Divider();Text("Relative cursor and digital movement").font(.headline)
                Text("A/D/W/S are digital keys. Down can consume material. Equipment and More do not pause the game. Pointer mode is explicit and can get out of sync with external input.").font(.caption)
                slider("Horizontal deadzone",m.deadZone,0.05...0.6) { v in edit { $0.digitalMovement?.deadZone=v } }
                slider("Levitation threshold",m.flightThreshold,0.15...0.9) { v in edit { $0.digitalMovement?.flightThreshold=v } }
                slider("Down / Eat threshold",m.downThreshold,0.4...1.5) { v in edit { $0.digitalMovement?.downThreshold=v } }
                slider("Threshold hysteresis",m.hysteresis,0.01...min(0.14,min(m.deadZone,m.flightThreshold)-0.001)) { v in edit { $0.digitalMovement?.hysteresis=v } }
                slider("Firing sensitivity multiplier",c.firingMultiplier,0.1...3) { v in edit { $0.cursorControls?.firingMultiplier=v } }
                slider("Radial position X",c.radialX,0...1) { v in edit { $0.cursorControls?.radialX=v } }
                slider("Radial position Y",c.radialY,0...1) { v in edit { $0.cursorControls?.radialY=v } }
                slider("Radial radius",c.radialRadius,0.18...0.4) { v in edit { $0.cursorControls?.radialRadius=v } }
                region("Aim area",(pad ? p.pad:p.phone).aimRect,move:false)
                region("Floating movement area",(pad ? p.pad:p.phone).movementRect ?? .init(x:0,y:0.25,width:0.42,height:0.75),move:true)
                ForEach([m.up,c.throwAction,m.down],id:\.self) { id in
                    if let action=p.actions.first(where:{$0.id==id}) {
                        Toggle("Direct \(action.label) button",isOn:Binding(get:{(pad ? p.pad:p.phone).controls.contains { $0.action==id && $0.role=="button" }},set:{ on in edit { value in
                            var l=pad ? value.pad:value.phone
                            l.controls.removeAll { $0.action==id && $0.role=="button" }
                            if on { l.controls.append(.init(id:"optional-"+id,action:id,role:"button",x:0.5,y:0.88,radius:0.06,hitRadius:0.06,opacity:0.65,labelPlacement:"inside")) }
                            if pad {value.pad=l}else{value.phone=l}
                        } }))
                    }
                }
                Text("Gyro is unavailable for this cursor profile.").font(.caption)
            }
        }
    }
    func region(_ title:String,_ r:BCDControlPack.Layout.Rect,move:Bool) -> some View {
        VStack {
            Text(title).font(.subheadline)
            slider("X",r.x,0...max(0,1-r.width)) { v in setRect(move:move) { $0.x=v } }
            slider("Y",r.y,0...max(0,1-r.height)) { v in setRect(move:move) { $0.y=v } }
            slider("Width",r.width,(move ? 0.1:0.25)...max(move ? 0.1:0.25,1-r.x)) { v in setRect(move:move) { $0.width=v } }
            slider("Height",r.height,(move ? 0.1:0.25)...max(move ? 0.1:0.25,1-r.y)) { v in setRect(move:move) { $0.height=v } }
        }
    }
    func setRect(move:Bool,_ change:(inout BCDControlPack.Layout.Rect)->Void) {
        edit { p in
            var l=pad ? p.pad:p.phone
            var rect=move ? (l.movementRect ?? .init(x:0,y:0.25,width:0.42,height:0.75)):l.aimRect
            change(&rect);if move {l.movementRect=rect}else{l.aimRect=rect}
            if pad {p.pad=l}else{p.phone=l}
        }
    }
}
