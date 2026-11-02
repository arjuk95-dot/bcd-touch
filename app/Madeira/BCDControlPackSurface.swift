// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001, 2026-11-01. One surface owns every finger for its entire lifetime.
import SwiftUI
import UIKit

/// Pack focus follows visible UIKit presentations even on a touch-only device.
/// HardwareInput's cached keyboard/mouse focus is not polled without hardware.
@MainActor final class BCDPackFocus: ObservableObject {
    static let shared = BCDPackFocus()
    static let didLoseFocus = Notification.Name("BCDTouchPackDidLoseFocus")
    @Published private(set) var gameFocused = true
    @Published private(set) var blockedByPresentation = false
    private weak var overlayWindow: UIWindow?
    private var timer: Timer?
    private var monitoring = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.gameFocused = false; GamepadInput.shared.packFocusLost()
                    NotificationCenter.default.post(name: Self.didLoseFocus, object: nil)
                }
            })
        }
        for name in [UIApplication.didBecomeActiveNotification, UIWindow.didBecomeKeyNotification, UIWindow.didResignKeyNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.refresh() }
            })
        }
    }
    func observe(_ window: UIWindow) {
        guard overlayWindow !== window else { return }
        overlayWindow = window
        DispatchQueue.main.async { [weak self] in _ = self?.refresh() }
    }
    func setMonitoring(_ enabled: Bool) {
        monitoring = enabled
        if enabled, timer == nil {
            let clock = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { _ = self?.refresh() }
            }
            RunLoop.main.add(clock, forMode: .common); timer = clock
        } else if !enabled { timer?.invalidate(); timer = nil }
        refresh()
    }
    private static var windows: [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
    }
    /// A presentation containing the game's view is its host, not a dialog.
    static func hasPresentation(_ controller: UIViewController?, gameView: UIView?) -> Bool {
        guard let controller else { return false }
        if controller is UIAlertController { return true }
        if let presented = controller.presentedViewController {
            if let gameView, let host = presented.viewIfLoaded, gameView.isDescendant(of: host) {
                return hasPresentation(presented, gameView: gameView)
            }
            return true
        }
        return controller.children.contains {
            $0.viewIfLoaded?.window != nil && hasPresentation($0, gameView: gameView)
        }
    }
    static func blockingPresentation(outside overlay: UIWindow) -> Bool {
        let candidates = overlay.windowScene?.windows ?? windows
        return candidates.contains {
            $0 !== overlay && $0.windowLevel.rawValue <= overlay.windowLevel.rawValue && !$0.isHidden && $0.alpha > 0.01 &&
            hasPresentation($0.rootViewController, gameView: MetalBackedView.keyboardTarget)
        }
    }
    @discardableResult func refresh() -> Bool {
        guard monitoring else { return gameFocused }
        let candidates = overlayWindow?.windowScene?.windows ?? Self.windows
        let presented = candidates.filter {
            !$0.isHidden && $0.alpha > 0.01 && Self.hasPresentation($0.rootViewController, gameView: MetalBackedView.keyboardTarget)
        }
        let active = UIApplication.shared.applicationState == .active &&
            (overlayWindow?.windowScene == nil || overlayWindow?.windowScene?.activationState == .foregroundActive)
        let focused = active && presented.isEmpty
        let blocked = presented.contains { window in
            window !== overlayWindow && (overlayWindow == nil || window.windowLevel.rawValue <= overlayWindow!.windowLevel.rawValue)
        }
        if gameFocused && !focused {
            GamepadInput.shared.packFocusLost()
            NotificationCenter.default.post(name: Self.didLoseFocus, object: nil)
        }
        if gameFocused != focused { gameFocused = focused }
        if blockedByPresentation != blocked { blockedByPresentation = blocked }
        return focused
    }
}

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
        var radialCenter: CGPoint?
    }
    private var pack: BCDControlPack?
    private var context = "onFoot"
    private var debug = false, editing = false
    private var fingers: [AnyHashable: Finger] = [:]
    private var keyHolds: [UUID: Int32] = [:]
    private var mouseHolds: [UUID: String] = [:]
    private var previousSize = CGSize.zero
    private var epoch = UUID()
    private var pulses = Set<UUID>()
    init() {
        super.init(frame: .zero); backgroundColor = .clear; isMultipleTouchEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: BCDPackFocus.didLoseFocus, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func interrupted() { clear() }
    func configure(_ p: BCDControlPack, context: String, debug: Bool, editing: Bool) {
        if pack != p || self.context != context || self.editing != editing { clear() }
        pack = p; self.context = context; self.debug = debug; self.editing = editing; setNeedsDisplay()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window { BCDPackFocus.shared.observe(window) } else { clear() }
    }
    override func layoutSubviews() { super.layoutSubviews(); if bounds.size != previousSize { clear(); previousSize = bounds.size }; setNeedsDisplay() }
    private var pad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var layout: BCDControlPack.Layout? { pad ? pack?.pad : pack?.phone }
    private var safe: CGRect { bounds.inset(by: safeAreaInsets) }
    private var unit: CGFloat { min(safe.width, safe.height) }
    private func center(_ c: BCDControlPack.Control) -> CGPoint { CGPoint(x: safe.minX + c.x * safe.width, y: safe.minY + c.y * safe.height) }
    private func action(_ id: String) -> BCDControlPack.Action? { pack?.actions.first { $0.id == id && $0.contexts.contains(context) } }
    private var radialActions: [BCDControlPack.Action] { (pack?.radial ?? []).compactMap { action($0) } }
    private func visible(_ c: BCDControlPack.Control) -> Bool {
        if c.role == "radial" { return !radialActions.isEmpty }
        if c.role == "gesture" { return pack?.gestures.contains { action($0.action) != nil } == true }
        return action(c.action) != nil
    }
    private var movementControl: BCDControlPack.Control? {
        guard pack?.inputMode == "controller" else { return nil }
        return layout?.controls.first { $0.role == "move" && visible($0) }
    }
    /// Reserve the lower left area before look acquisition; buttons keep priority.
    var movementStartRegion: CGRect {
        guard movementControl != nil, let layout else { return .zero }
        return CGRect(x: safe.minX, y: safe.minY + safe.height * 0.4,
                      width: safe.width * min(0.4, layout.aimRect.x), height: safe.height * 0.6)
    }
    var activeTouchRoles: [String] { fingers.values.map(\.role).sorted() }
    var movementVisual: (origin: CGPoint, thumb: CGPoint, radius: CGFloat)? {
        guard let finger = fingers.values.first(where: { $0.role == "move" }) else { return nil }
        let radius = max(CGFloat(1), unit * CGFloat(finger.control?.radius ?? 0.14))
        let dx = finger.last.x - finger.start.x, dy = finger.last.y - finger.start.y
        let scale = max(1, hypot(dx, dy) / radius)
        return (finger.start, CGPoint(x: finger.start.x + dx / scale, y: finger.start.y + dy / scale), radius)
    }
    private func radialCenter(at point: CGPoint) -> CGPoint {
        let font=UIFont.boldSystemFont(ofSize:12)
        let width=radialActions.map { ($0.label as NSString).size(withAttributes:[.font:font]).width }.max() ?? 0
        let xInset=min(safe.width/2,unit*0.2+width/2+8), yInset=min(safe.height/2,unit*0.2+20)
        return CGPoint(x:max(safe.minX+xInset,min(safe.maxX-xInset,point.x)),
                       y:max(safe.minY+yInset,min(safe.maxY-yInset,point.y)))
    }
    private func radialLabels(_ finger: Finger) -> [(action: BCDControlPack.Action, frame: CGRect)] {
        let center=finger.radialCenter ?? finger.start
        return radialActions.enumerated().map { i, action in
            let angle=Double(i)/Double(max(1,radialActions.count)) * .pi * 2 + .pi/Double(max(1,radialActions.count))
            let point=CGPoint(x:center.x+CGFloat(Foundation.cos(angle))*unit*0.2,y:center.y+CGFloat(Foundation.sin(angle))*unit*0.2)
            let size=(action.label as NSString).size(withAttributes:[.font:UIFont.boldSystemFont(ofSize:12)])
            return (action,CGRect(x:point.x-size.width/2,y:point.y-size.height/2,width:size.width,height:size.height))
        }
    }
    var radialLabelFrames: [CGRect] { fingers.values.filter { $0.role == "radial" }.flatMap { radialLabels($0).map { $0.frame } } }
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
        let delivery = ProcessInfo.processInfo.systemUptime
        for t in touches { beginTouch(ObjectIdentifier(t), at: t.location(in: self), time: t.timestamp, receivedAt: delivery) }
    }
    func beginTouch(_ identity: AnyHashable, at point: CGPoint, time: Double, receivedAt: Double? = nil) {
        guard UIApplication.shared.applicationState == .active, !LibraryModel.shared.blocksGameplayTouch,
              BCDPackFocus.shared.refresh(), let pack else { clear(); return }
        // Idempotent configuration keeps another finger's movement/fire held.
        GamepadInput.shared.configurePack(enabled: pack.inputMode == "controller", accepting: !editing, calibration: pack.aim)
        var control = layout?.controls.reversed().first { c in
            visible(c) && (editing || c.role != "move") &&
            hypot(point.x - center(c).x, point.y - center(c).y) <= c.hitRadius * unit
        }
        var role = editing ? "edit" : (control?.role ?? "look")
        if !editing, control == nil, let move = movementControl,
           movementStartRegion.contains(point) || hypot(point.x - center(move).x, point.y - center(move).y) <= move.hitRadius * unit {
            control = move
            role = fingers.values.contains(where: { $0.role == "move" }) ? "ignore" : "move"
        }
        var finger = Finger(role: role, control: control, start: point, last: point, time: time)
        if role == "radial" { finger.radialCenter = radialCenter(at: point) }
        if role == "look" || role == "fireAim" {
            GamepadInput.shared.packLook(owner: finger.owner, phase: 0, time: time, receivedAt: receivedAt)
        }
        if role == "move" { GamepadInput.shared.packTouch(owner: finger.owner, value: TouchPadAction.sample("LS")) }
        if let control, let binding = action(control.action), role == "button" || role == "fireAim" {
            if binding.behavior == "tap" { pulse(binding) }
            else if binding.behavior == "hold" { send(binding, owner: finger.owner) }
        }
        fingers[identity] = finger
        setNeedsDisplay()
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let delivery = ProcessInfo.processInfo.systemUptime
        for t in touches {
            // Publish one displacement/time interval per delivered batch. Replaying
            // every historical sample made the final sub-sample's tiny interval
            // dictate expiry, even when batches arrived only every 16-33 ms.
            let sample = ((event?.coalescedTouches(for: t) ?? []) + [t]).max { $0.timestamp < $1.timestamp } ?? t
            moveTouch(ObjectIdentifier(t), to: sample.location(in: self), time: sample.timestamp, receivedAt: delivery)
        }
    }
    func moveTouch(_ identity: AnyHashable, to point: CGPoint, time: Double, receivedAt: Double? = nil) {
        guard UIApplication.shared.applicationState == .active, !LibraryModel.shared.blocksGameplayTouch,
              BCDPackFocus.shared.refresh() else { clear(); return }
        guard var finger = fingers[identity], time > finger.time else { return }
        if finger.role == "look" || finger.role == "fireAim" {
            if pack?.inputMode == "controller" {
                GamepadInput.shared.packLook(owner: finger.owner, phase: 1, dx: Double(point.x - finger.last.x), dy: Double(point.y - finger.last.y), time: time, receivedAt: receivedAt)
            } else if let calibration = pack?.aim {
                HardwareInput.shared.postRelative(Int32(max(-30000, min(30000, Double(point.x - finger.last.x) * calibration.sensitivity * 2))),
                    Int32(max(-30000, min(30000, Double(point.y - finger.last.y) * calibration.sensitivity * calibration.vertical * 2 * (calibration.invertY ? -1 : 1)))))
            }
        } else if finger.role == "move" {
            let radius = max(CGFloat(1), unit * CGFloat(finger.control?.radius ?? 0.14))
            GamepadInput.shared.packTouch(owner: finger.owner, value: TouchPadAction.sample("LS", x: Double((point.x - finger.start.x) / radius), y: Double((finger.start.y - point.y) / radius)))
        } else if finger.role == "radial", !radialActions.isEmpty {
            let previous = finger.selection
            let center=finger.radialCenter ?? finger.start
            let dx = point.x - center.x, dy = point.y - center.y
            if hypot(point.x-finger.start.x, point.y-finger.start.y) > unit * 0.06 {
                let angle = atan2(dy, dx) + .pi * 2
                finger.selection = Int((angle.truncatingRemainder(dividingBy: .pi * 2)) / (.pi * 2) * Double(radialActions.count))
            } else { finger.selection = nil }
            if previous != finger.selection {
                release(finger.owner)
                if let index = finger.selection, radialActions[index].behavior == "hold" { send(radialActions[index], owner: finger.owner) }
            }
        }
        finger.last = point; finger.time = time; fingers[identity] = finger
        setNeedsDisplay()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, cancelled: false) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, cancelled: true) }
    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        for t in touches {
            endTouch(ObjectIdentifier(t), at: t.location(in: self), cancelled: cancelled)
        }
    }
    func endTouch(_ identity: AnyHashable, at point: CGPoint, cancelled: Bool) {
            guard let f = fingers.removeValue(forKey: identity) else { return }
            release(f.owner)
            defer { setNeedsDisplay() }
            guard !cancelled, !LibraryModel.shared.blocksGameplayTouch, BCDPackFocus.shared.refresh(), let pack else { return }
            if f.role == "radial", let index = f.selection, radialActions.indices.contains(index), radialActions[index].behavior != "hold" { pulse(radialActions[index]) }
            if f.role == "button" || f.role == "fireAim", let c = f.control, let a = action(c.action), a.behavior == "release" { pulse(a) }
            if f.role == "gesture" {
                let dx = point.x - f.start.x, dy = point.y - f.start.y
                if hypot(dx, dy) > 30 {
                    let kind = abs(dx) > abs(dy) ? (dx > 0 ? "swipeRight" : "swipeLeft") : (dy > 0 ? "swipeDown" : "swipeUp")
                    if let g = pack.gestures.first(where: { $0.kind == kind }), let a = action(g.action) { pulse(a) }
                }
            }
            if f.role == "edit", let c = f.control {
                var edited = pack; let p = point
                func change(_ controls: inout [BCDControlPack.Control]) {
                    if let i = controls.firstIndex(where: { $0.id == c.id }) {
                        controls[i].x += Double((p.x - f.start.x) / max(1, safe.width)); controls[i].y += Double((p.y - f.start.y) / max(1, safe.height))
                    }
                }
                if pad { change(&edited.pad.controls) } else { change(&edited.phone.controls) }
                BCDPackStore.shared.saveEdits(edited)
            }
    }
    override func draw(_ rect: CGRect) {
        guard let layout, let ctx = UIGraphicsGetCurrentContext() else { return }
        if debug {
            let a = layout.aimRect
            ctx.setFillColor(UIColor.green.withAlphaComponent(0.1).cgColor)
            ctx.fill(CGRect(x: safe.minX + a.x * safe.width, y: safe.minY + a.y * safe.height, width: a.width * safe.width, height: a.height * safe.height))
            if movementControl != nil {
                ctx.saveGState(); ctx.setStrokeColor(UIColor.cyan.cgColor); ctx.setLineDash(phase: 0, lengths: [5, 4])
                ctx.stroke(movementStartRegion); ctx.restoreGState()
            }
            let status = "Touch roles: " + activeTouchRoles.joined(separator: ", ")
            (status as NSString).draw(at: CGPoint(x: safe.minX + 8, y: safe.minY + 4),
                withAttributes: [.font:UIFont.monospacedSystemFont(ofSize:11, weight:.medium), .foregroundColor:UIColor.cyan])
        }
        for c in layout.controls where visible(c) {
            let p = center(c), r = c.radius * unit
            if c.role == "move", !editing {
                if let stick = movementVisual {
                    ctx.setLineWidth(1)
                    ctx.setStrokeColor(UIColor.white.withAlphaComponent(max(0.35, c.opacity)).cgColor)
                    ctx.strokeEllipse(in: CGRect(x: stick.origin.x - stick.radius, y: stick.origin.y - stick.radius,
                                                width: stick.radius * 2, height: stick.radius * 2))
                    let knob = stick.radius * 0.38
                    ctx.setFillColor(UIColor.white.withAlphaComponent(max(0.2, c.opacity * 0.7)).cgColor)
                    ctx.fillEllipse(in: CGRect(x: stick.thumb.x - knob, y: stick.thumb.y - knob, width: knob * 2, height: knob * 2))
                } else {
                    // An idle hint is not a fixed stick base or its hit region.
                    UIImage(systemName: "l.joystick")?.withTintColor(.white.withAlphaComponent(c.opacity * 0.6), renderingMode: .alwaysOriginal)
                        .draw(in: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24))
                }
                continue
            }
            let circle = CGRect(x: p.x-r, y: p.y-r, width: r*2, height: r*2)
            let pressed = fingers.values.contains { $0.control?.id == c.id }
            if pressed { ctx.setFillColor(UIColor.white.withAlphaComponent(0.12).cgColor); ctx.fillEllipse(in: circle) }
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(pressed ? 0.9 : c.opacity * 0.65).cgColor)
            ctx.setLineWidth(pressed ? 1.5 : 1); ctx.strokeEllipse(in: circle)
            let a = action(c.action)
            let icon = c.role == "radial" ? "circle.grid.2x2" : (a?.icon ?? "hand.draw")
            if let image = UIImage(systemName: icon)?.withTintColor(.white.withAlphaComponent(c.opacity), renderingMode: .alwaysOriginal) {
                image.draw(in: CGRect(x: p.x-r*0.42, y: p.y-r*0.42, width: r*0.84, height: r*0.84))
            } else {
                ((a?.output ?? "…") as NSString).draw(at: CGPoint(x:p.x-r*0.5,y:p.y-8),withAttributes:[.font:UIFont.boldSystemFont(ofSize:14),.foregroundColor:UIColor.white])
            }
            let label = (c.role == "radial" ? "Actions" : (a?.label ?? c.role)) + (editing ? " [\(a?.output ?? "") ]" : "")
            (label as NSString).draw(at: CGPoint(x: p.x-r, y: p.y+r+2), withAttributes: [.font:UIFont.systemFont(ofSize: 10), .foregroundColor:UIColor.white.withAlphaComponent(c.opacity)])
            if debug {
                let h = c.hitRadius * unit
                ctx.setStrokeColor(UIColor.cyan.cgColor); ctx.strokeEllipse(in: CGRect(x:p.x-h,y:p.y-h,width:h*2,height:h*2))
            }
        }
        for f in fingers.values where f.role == "radial" {
            for (i, label) in radialLabels(f).enumerated() {
                (label.action.label as NSString).draw(at:label.frame.origin, withAttributes:[.font:UIFont.boldSystemFont(ofSize:12), .foregroundColor:f.selection == i ? UIColor.yellow : UIColor.white])
            }
        }
    }
}
