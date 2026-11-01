// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001, 2026-11-01. One surface owns every finger for its entire lifetime.
import SwiftUI
import UIKit

struct BCDPackSurface: UIViewRepresentable {
    var pack: BCDControlPack; var context: String; var debug: Bool; var editing: Bool
    func makeUIView(context: Context) -> BCDPackView { BCDPackView() }
    func updateUIView(_ v: BCDPackView, context: Context) { v.configure(pack, context: self.context, debug: debug, editing: editing) }
    static func dismantleUIView(_ v: BCDPackView, coordinator: ()) { v.clear() }
}

final class BCDPackView: UIView {
    struct Finger {
        var owner = UUID()
        var role: String
        var control: BCDControlPack.Control?
        var start: CGPoint
        var last: CGPoint
        var time: Double
        var selection: Int?
    }
    private var pack: BCDControlPack?
    private var context = "onFoot"
    private var debug = false, editing = false
    private var fingers: [ObjectIdentifier: Finger] = [:]
    private var keyHolds: [UUID: Int32] = [:]
    private var mouseHolds: [UUID: String] = [:]
    private var previousSize = CGSize.zero
    private var epoch = UUID()
    private var pulses = Set<UUID>()
    init() {
        super.init(frame: .zero); backgroundColor = .clear; isMultipleTouchEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func interrupted() { clear() }
    func configure(_ p: BCDControlPack, context: String, debug: Bool, editing: Bool) {
        if pack != p || self.context != context || self.editing != editing { clear() }
        pack = p; self.context = context; self.debug = debug; self.editing = editing; setNeedsDisplay()
    }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { clear() } }
    override func layoutSubviews() { super.layoutSubviews(); if bounds.size != previousSize { clear(); previousSize = bounds.size }; setNeedsDisplay() }
    private var pad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var layout: BCDControlPack.Layout? { pad ? pack?.pad : pack?.phone }
    private var safe: CGRect { bounds.inset(by: safeAreaInsets) }
    private var unit: CGFloat { min(safe.width, safe.height) }
    private func center(_ c: BCDControlPack.Control) -> CGPoint { CGPoint(x: safe.minX + c.x * safe.width, y: safe.minY + c.y * safe.height) }
    private func action(_ id: String) -> BCDControlPack.Action? { pack?.actions.first { $0.id == id && $0.contexts.contains(context) } }
    func clear() {
        epoch = UUID()
        for f in fingers.values { release(f.owner) }
        for owner in pulses { release(owner) }; pulses.removeAll()
        fingers.removeAll(); setNeedsDisplay()
    }
    private func release(_ owner: UUID) {
        GamepadInput.shared.packTouch(owner: owner, value: nil)
        GamepadInput.shared.packLook(owner: owner, phase: 2, time: ProcessInfo.processInfo.systemUptime)
        if let key = keyHolds.removeValue(forKey: owner), !keyHolds.values.contains(key) { winios_post_key(key, 0) }
        if let mouse = mouseHolds.removeValue(forKey: owner), !mouseHolds.values.contains(mouse) { winios_pointer(0, 0, mouse == "mouse:left" ? 4 : 16, 0) }
    }
    private func send(_ a: BCDControlPack.Action, owner: UUID) {
        guard let p = pack else { return }
        if p.inputMode == "controller" { GamepadInput.shared.packTouch(owner: owner, value: TouchPadAction.sample(a.output)); return }
        if a.output.hasPrefix("key:"), let key = Int32(a.output.dropFirst(4)) {
            let already = keyHolds.values.contains(key); keyHolds[owner] = key
            if !already { winios_post_key(key, 1) }
        } else if ["mouse:left", "mouse:right"].contains(a.output) {
            let already = mouseHolds.values.contains(a.output); mouseHolds[owner] = a.output
            if !already { winios_pointer(0, 0, a.output == "mouse:left" ? 2 : 8, 0) }
        } else { GamepadInput.shared.packTouch(owner: owner, value: TouchPadAction.sample(a.output)) }
    }
    private func pulse(_ a: BCDControlPack.Action) {
        let owner = UUID(), generation = epoch
        pulses.insert(owner); send(a, owner: owner)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.epoch == generation else { return }
            self.release(owner); self.pulses.remove(owner)
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard UIApplication.shared.applicationState == .active, !LibraryModel.shared.blocksGameplayTouch else { clear(); return }
        for t in touches {
            let point = t.location(in: self)
            let c = layout?.controls.reversed().first { c in
                (c.role == "radial" || c.role == "gesture" || action(c.action) != nil) && hypot(point.x - center(c).x, point.y - center(c).y) <= c.hitRadius * unit
            }
            let role = editing ? "edit" : (c?.role ?? "look")
            var f = Finger(role: role, control: c, start: point, last: point, time: t.timestamp)
            if role == "look" || role == "fireAim" {
                GamepadInput.shared.packLook(owner: f.owner, phase: 0, time: t.timestamp)
            }
            if let c, let a = action(c.action), (role == "button" || role == "fireAim") {
                if a.behavior == "tap" { pulse(a) } else if a.behavior == "hold" { send(a, owner: f.owner) }
            }
            if role == "radial" { f.selection = nil }
            fingers[ObjectIdentifier(t)] = f
        }
        setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard UIApplication.shared.applicationState == .active, !LibraryModel.shared.blocksGameplayTouch else { clear(); return }
        for t in touches {
            guard var f = fingers[ObjectIdentifier(t)] else { continue }
            let samples = event?.coalescedTouches(for: t) ?? [t]
            for sample in samples {
                let p = sample.location(in: self)
                if f.role == "look" || f.role == "fireAim" {
                    if pack?.inputMode == "controller" {
                        GamepadInput.shared.packLook(owner: f.owner, phase: 1, dx: Double(p.x - f.last.x), dy: Double(p.y - f.last.y), time: sample.timestamp)
                    } else if let calibration = pack?.aim {
                        HardwareInput.shared.postRelative(Int32(max(-30000, min(30000, Double(p.x - f.last.x) * calibration.sensitivity * 2))),
                            Int32(max(-30000, min(30000, Double(p.y - f.last.y) * calibration.sensitivity * calibration.vertical * 2 * (calibration.invertY ? -1 : 1)))))
                    }
                } else if f.role == "move" {
                    let r = max(1, unit * 0.14)
                    GamepadInput.shared.packTouch(owner: f.owner, value: TouchPadAction.sample("LS", x: Double((p.x - f.start.x) / r), y: Double((f.start.y - p.y) / r)))
                } else if f.role == "radial", let pack, !pack.radial.isEmpty {
                    let dx = p.x - f.start.x, dy = p.y - f.start.y
                    if hypot(dx, dy) > unit * 0.06 {
                        let angle = atan2(dy, dx) + .pi * 2
                        f.selection = Int((angle.truncatingRemainder(dividingBy: .pi * 2)) / (.pi * 2) * Double(pack.radial.count))
                    } else { f.selection = nil }
                }
                f.last = p
            }
            fingers[ObjectIdentifier(t)] = f
        }
        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, cancelled: false) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, cancelled: true) }
    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        for t in touches {
            guard let f = fingers.removeValue(forKey: ObjectIdentifier(t)) else { continue }
            release(f.owner)
            guard !cancelled, let pack else { continue }
            if f.role == "radial", let index = f.selection, let a = action(pack.radial[index]) { pulse(a) }
            if f.role == "button" || f.role == "fireAim", let c = f.control, let a = action(c.action), a.behavior == "release" { pulse(a) }
            if f.role == "gesture" {
                let p = t.location(in: self), dx = p.x - f.start.x, dy = p.y - f.start.y
                if hypot(dx, dy) > 30 {
                    let kind = abs(dx) > abs(dy) ? (dx > 0 ? "swipeRight" : "swipeLeft") : (dy > 0 ? "swipeDown" : "swipeUp")
                    if let g = pack.gestures.first(where: { $0.kind == kind }), let a = action(g.action) { pulse(a) }
                }
            }
            if f.role == "edit", let c = f.control {
                var edited = pack; let p = t.location(in: self)
                func change(_ controls: inout [BCDControlPack.Control]) {
                    if let i = controls.firstIndex(where: { $0.id == c.id }) {
                        controls[i].x += Double((p.x - f.start.x) / max(1, safe.width)); controls[i].y += Double((p.y - f.start.y) / max(1, safe.height))
                    }
                }
                if pad { change(&edited.pad.controls) } else { change(&edited.phone.controls) }
                BCDPackStore.shared.saveEdits(edited)
            }
        }
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let layout, let ctx = UIGraphicsGetCurrentContext() else { return }
        if debug {
            let a = layout.aimRect
            ctx.setFillColor(UIColor.green.withAlphaComponent(0.1).cgColor)
            ctx.fill(CGRect(x: safe.minX + a.x * safe.width, y: safe.minY + a.y * safe.height, width: a.width * safe.width, height: a.height * safe.height))
        }
        for c in layout.controls where c.role == "radial" || c.role == "gesture" || action(c.action) != nil {
            let p = center(c), r = c.radius * unit
            let circle = CGRect(x: p.x-r, y: p.y-r, width: r*2, height: r*2)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(c.opacity * 0.65).cgColor); ctx.setLineWidth(1); ctx.strokeEllipse(in: circle)
            let a = action(c.action)
            let icon = a?.icon ?? (c.role == "radial" ? "circle.grid.2x2" : "hand.draw")
            if let image = UIImage(systemName: icon)?.withTintColor(.white.withAlphaComponent(c.opacity), renderingMode: .alwaysOriginal) {
                image.draw(in: CGRect(x: p.x-r*0.42, y: p.y-r*0.42, width: r*0.84, height: r*0.84))
            }
            let label = (a?.label ?? c.role) + (editing ? " [\(a?.output ?? "") ]" : "")
            (label as NSString).draw(at: CGPoint(x: p.x-r, y: p.y+r+2), withAttributes: [.font:UIFont.systemFont(ofSize: 10), .foregroundColor:UIColor.white.withAlphaComponent(c.opacity)])
            if debug {
                let h = c.hitRadius * unit
                ctx.setStrokeColor(UIColor.cyan.cgColor); ctx.strokeEllipse(in: CGRect(x:p.x-h,y:p.y-h,width:h*2,height:h*2))
            }
        }
        for f in fingers.values where f.role == "radial" {
            for (i, id) in (pack?.radial ?? []).enumerated() {
                let angle = Double(i) / Double(max(1, pack?.radial.count ?? 1)) * .pi * 2 + .pi / Double(max(1, pack?.radial.count ?? 1))
                let p = CGPoint(x:f.start.x + cos(angle)*unit*0.2, y:f.start.y + sin(angle)*unit*0.2)
                ((action(id)?.label ?? id) as NSString).draw(at:p, withAttributes:[.font:UIFont.boldSystemFont(ofSize:12), .foregroundColor:f.selection == i ? UIColor.yellow : UIColor.white])
            }
        }
    }
}
