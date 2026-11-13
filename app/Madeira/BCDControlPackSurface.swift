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
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
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
        var began: Double = 0
        var queenTravel: CGFloat = 0
        var selection: Int?
        var radialCenter: CGPoint?
        var toggleWasOn = false
        var slideArmed = false
        var slideFired = false
        var didDrag = false
        var sulfurSprint = BCDSulfurSprintState()
        var surfaceTap: BCDPackSurfaceTap? = nil
    }
    private var pack: BCDControlPack?
    private var context = "onFoot"
    private var queen = BCDQueensGesturePolicy()
    private var queenFinger: AnyHashable?
    private let queenOwner = UUID()
    private var queenTimer: Timer?
    private var utilityTouches: [AnyHashable:(CGPoint,Double)] = [:]
    private var utilityInvalid = false
    private var utilityEnded = 0
    private var isQueen: Bool { pack?.id == "queens-domain-v6" }
    private func queenEvents(_ events:[BCDQueensGesturePolicy.Event]) {
        for e in events {
            switch e {
            case .attackDown: if let a=action("attack") {send(a,owner:queenOwner)}
            case .attackUp: release(queenOwner)
            case .equipment: if let a=action("equipment") {pulse(a)}
            case .journal: if let a=action("journal") {pulse(a)}
            }
        }
    }
    private func finishQueen(_ id:AnyHashable,point:CGPoint,time:Double,cancelled:Bool) {
        if utilityTouches[id] != nil {
            utilityEnded += 1
            if cancelled {utilityInvalid=true}
            if let (start,t)=utilityTouches[id],!point.x.isFinite || !point.y.isFinite || !time.isFinite || time<t || hypot(point.x-start.x,point.y-start.y)>12 || time-t>0.3 {utilityInvalid=true}
            if utilityEnded == utilityTouches.count {
                if !utilityInvalid {queenEvents(queen.twoFingerTap(time:time))} else {queen.cancelPendingUtility()}
                utilityTouches.removeAll();utilityEnded=0;utilityInvalid=false
            }
        } else if queenFinger == id {
            if cancelled {queenEvents(queen.cancelAttack())}
            else {
                let events=queen.end(at:point,time:time)
                // Tap pulse must persist across engine input delivery frames.
                if events == [.attackDown,.attackUp],let a=action("attack") {pulse(a)} else {queenEvents(events)}
            }
            queenFinger=nil
        }
    }
    private var debug = false, editing = false
    private var fingers: [AnyHashable: Finger] = [:]
    private var keyHolds: [UUID: [Int32]] = [:]
    private var mouseHolds: [UUID: String] = [:]
    private var toggles: [String: UUID] = [:]
    private var previousSize = CGSize.zero
    private var epoch = UUID()
    private var pulses = Set<UUID>()
    private var pulseActions: [UUID: String] = [:]
    private var tapPulses = BCDPackTapPulses()
    private var tapOutputOwner = UUID()
    private var tapGate: (action: String, owner: UUID, output: String)?
    private var tapTimer: Timer?
    private(set) var cursorEngine: BCDCursorPack?
    private var cursorTimer: Timer?
    init() {
        super.init(frame: .zero); backgroundColor = .clear; isMultipleTouchEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: BCDPackFocus.didLoseFocus, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { queenTimer?.invalidate();cursorTimer?.invalidate();tapTimer?.invalidate();NotificationCenter.default.removeObserver(self) }
    @objc private func interrupted() { clear() }
    @objc private func rotated() { if cursorEngine != nil || pack?.gestures.contains(where: { $0.kind == "tap" }) == true { clear() } }
    func configure(_ p: BCDControlPack, context: String, debug: Bool, editing: Bool) {
        let changed = pack != p || self.context != context || self.editing != editing
        if changed { clear();cursorEngine = nil;cursorTimer?.invalidate();cursorTimer=nil }
        pack = p; self.context = context;
        if (p.id != "queens-domain-v6" && !p.id.hasPrefix("sulfur")) || editing {queenTimer?.invalidate();queenTimer=nil}
        if (p.id == "queens-domain-v6" || p.id.hasPrefix("sulfur")) && !editing && queenTimer == nil {
            queen.journalEnabled=p.actions.contains{$0.id == "journal"}
            let timer=Timer(timeInterval:0.02,repeats:true){[weak self] _ in
                MainActor.assumeIsolated {guard let self else{return}
                    if LibraryModel.shared.blocksGameplayTouch || !BCDPackFocus.shared.refresh(){self.clear();return}
                    self.queenEvents(self.queen.advance(time:ProcessInfo.processInfo.systemUptime))
                    if self.pack?.id.hasPrefix("sulfur") == true {
                        for key in Array(self.fingers.keys) {
                            guard var f=self.fingers[key],f.role == "move" else{continue}
                            let r=max(CGFloat(1),self.unit * CGFloat(f.control?.radius ?? 0.14))
                            let emit=BCDSulfurSprintUpdate(&f.sulfurSprint,Double((f.last.x-f.start.x)/r),Double((f.last.y-f.start.y)/r),ProcessInfo.processInfo.systemUptime,BCDPackStore.shared.sulfurSprintAllowed ? 1:0)
                            self.fingers[key]=f
                            if emit != 0,let a=self.action("sprint") {self.pulse(a)}
                        }
                    }
                }
            };RunLoop.main.add(timer,forMode:.common);queenTimer=timer
        }
         self.debug = debug; self.editing = editing; setNeedsDisplay()
        if p.cursorControls != nil && p.contexts.contains(context) && !editing && cursorEngine == nil {
            cursorEngine = BCDCursorPack(pack:p,pad:pad)
            if context == "pointer" { cursorEngine?.switchMode(.pointer) }
            else if BCDPackStore.shared.pack?.id == p.id && BCDPackStore.shared.pack?.identity == p.identity { cursorEngine?.switchMode(BCDPackStore.shared.cursorMode) }
            let clock=Timer(timeInterval:1.0/120.0,repeats:true) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else{return};self.cursorEngine?.tick(ProcessInfo.processInfo.systemUptime);self.flushCursor() }
            }
            RunLoop.main.add(clock,forMode:.common);cursorTimer=clock
        }
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
    func controlCenter(_ c: BCDControlPack.Control) -> CGPoint {
        let frame = c.coordinateSpace == "screen" ? bounds : safe
        return CGPoint(x: frame.minX + c.x * frame.width, y: frame.minY + c.y * frame.height)
    }
    private func center(_ c: BCDControlPack.Control) -> CGPoint {
        let origin = controlCenter(c)
        if editing, let finger = fingers.values.first(where: { $0.role == "edit" && $0.control?.id == c.id }) {
            return bounded(CGPoint(x: origin.x + finger.last.x - finger.start.x, y: origin.y + finger.last.y - finger.start.y))
        }
        return origin
    }
    private func bounded(_ point: CGPoint) -> CGPoint {
        CGPoint(x: max(bounds.minX, min(bounds.maxX, point.x)), y: max(bounds.minY, min(bounds.maxY, point.y)))
    }
    func positionedControl(_ c: BCDControlPack.Control, at point: CGPoint) -> BCDControlPack.Control {
        var result = c; let point = bounded(point)
        result.coordinateSpace = "screen"
        result.x = Double((point.x - bounds.minX) / max(1, bounds.width))
        result.y = Double((point.y - bounds.minY) / max(1, bounds.height))
        return result
    }
    private func action(_ id: String) -> BCDControlPack.Action? { pack?.actions.first { $0.id == id && $0.contexts.contains(context) } }
    private var radialActions: [BCDControlPack.Action] { (pack?.radial ?? []).compactMap { action($0) } }
    private func visible(_ c: BCDControlPack.Control) -> Bool {
        if let pack, !editing, BCDTenebrisOwnerCompatibility.hiddenAttack(c,in:pack) {return false}
        if isQueen && c.action == "attack" && c.role == "gesture" { return false }
        if c.role == "radial" { return !radialActions.isEmpty }
        if c.role == "gesture" { return pack?.gestures.contains { action($0.action) != nil } == true }
        return action(c.action) != nil
    }
    private var movementControl: BCDControlPack.Control? {
        guard pack?.inputMode == "controller" || pack?.digitalMovement != nil else { return nil }
        return layout?.controls.first { $0.role == "move" && visible($0) }
    }
    /// Reserve the lower left area before look acquisition; buttons keep priority.
    var movementStartRegion: CGRect {
        guard movementControl != nil, let layout else { return .zero }
        if let r = layout.movementRect {
            return CGRect(x: bounds.minX + r.x * bounds.width, y: bounds.minY + r.y * bounds.height, width: r.width * bounds.width, height: r.height * bounds.height)
        }
        return CGRect(x: safe.minX, y: safe.minY + safe.height * 0.4,
                      width: safe.width * min(0.4, layout.aimRect.x), height: safe.height * 0.6)
    }
    var activeTouchRoles: [String] { (fingers.values.map(\.role) + (cursorEngine?.fingers.values.map(\.role) ?? [])).sorted() }
    var toggledActionIDs: [String] { toggles.keys.sorted() }
    var movementVisual: (origin: CGPoint, thumb: CGPoint, radius: CGFloat)? {
        if let f=cursorEngine?.movementFinger {
            let radius=max(CGFloat(1),unit*CGFloat(movementControl?.radius ?? 0.14))
            let dx=f.last.x-f.start.x,dy=f.last.y-f.start.y,scale=max(1,hypot(dx,dy)/radius)
            return (f.start,CGPoint(x:f.start.x+dx/scale,y:f.start.y+dy/scale),radius)
        }
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
        queenEvents(queen.cancel());queenFinger=nil;utilityTouches.removeAll();utilityEnded=0;utilityInvalid=false
        cursorEngine?.cancel(resetMode:false);flushCursor()
        cancelSurfaceTaps()
        epoch = UUID()
        for f in fingers.values { release(f.owner) }
        for owner in pulses { release(owner) }; pulses.removeAll()
        pulseActions.removeAll()
        clearToggles()
        fingers.removeAll(); setNeedsDisplay()
    }
    private func cursorGeometry() {
        guard let engine=cursorEngine else{return}
        engine.bounds=bounds;engine.safe=safe
        let host=MetalHostView.shared
        engine.viewport=host.window != nil && host.bounds.width>0 ? host.bounds.size:safe.size
        var width:Int32=0,height:Int32=0;winios_screen_size(&width,&height)
        engine.guest=CGSize(width:width>0 ? Int(width):960,height:height>0 ? Int(height):540)
    }
    private func flushCursor(redraw: Bool = false) {
        if let engine=cursorEngine,BCDPackStore.shared.pack?.id == pack?.id,BCDPackStore.shared.pack?.identity == pack?.identity { BCDPackStore.shared.cursorMode=engine.mode }
        let events=cursorEngine?.drain() ?? []
        for event in events {
            switch event {
            case .motion(let x,let y): HardwareInput.shared.postCursorPackRelative(x,y)
            case .button(let output,let down):
                if let key=BCDPackCatalog.keyCodes(output)?.first { winios_post_key(key,down ? 1:0) }
                else { winios_pointer(0,0,output=="mouse:left" ? (down ? 2:4):(down ? 8:16),0) }
            case .customize: BCDPackStore.shared.editing=true
            }
        }
        if redraw || !events.isEmpty { setNeedsDisplay() }
    }
    private func clearToggles() {
        cancelSurfaceTaps()
        let owners = Array(toggles.values); toggles.removeAll()
        for owner in owners { release(owner) }
        setNeedsDisplay()
    }
    private func setToggle(_ a: BCDControlPack.Action, enabled: Bool) {
        if enabled, toggles[a.id] == nil {
            let owner = UUID(); toggles[a.id] = owner; send(a, owner: owner)
        } else if !enabled, let owner = toggles.removeValue(forKey: a.id) {
            if tapGate?.action == a.id { cancelSurfaceTaps() }
            release(owner)
        }
        setNeedsDisplay()
    }
    private func cancelSurfaceTaps(invalidateTouches: Bool = true) {
        let active = tapGate != nil || !tapPulses.idle
        tapTimer?.invalidate();tapTimer=nil;tapPulses.cancel();tapGate=nil
        if active { release(tapOutputOwner) }
        // Clearing a gate cannot re-arm a touch already resting on the screen.
        if invalidateTouches { for key in fingers.keys { fingers[key]?.surfaceTap=nil } }
    }
    private func surfaceTapEdge(_ edge: Bool) {
        if edge, let id=tapGate?.output, let a=action(id) {
            // A user can rebind the tap output to Menu. Its own pulse must outlive
            // clearing the Aim gate, while remaining independently releasable.
            if a.output == "Menu" { cancelSurfaceTaps();pulse(a) }
            else { send(a,owner:tapOutputOwner) }
        }
        else { release(tapOutputOwner) }
        setNeedsDisplay()
    }
    private func queueSurfaceTap(_ candidate: BCDPackSurfaceTap) {
        guard toggles[candidate.gate] == candidate.gateOwner else { return }
        if tapGate?.owner != candidate.gateOwner || tapGate?.output != candidate.action {
            cancelSurfaceTaps(invalidateTouches:false)
            tapGate=(candidate.gate,candidate.gateOwner,candidate.action)
        }
        if let edge=tapPulses.enqueue(now:ProcessInfo.processInfo.systemUptime) { surfaceTapEdge(edge) }
        if tapTimer == nil {
            let timer=Timer(timeInterval:1.0/120.0,repeats:true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard let gate=self.tapGate, self.toggles[gate.action] == gate.owner,
                          !LibraryModel.shared.blocksGameplayTouch, BCDPackFocus.shared.refresh() else {
                        self.cancelSurfaceTaps();return
                    }
                    if let edge=self.tapPulses.advance(now:ProcessInfo.processInfo.systemUptime) { self.surfaceTapEdge(edge) }
                    if self.tapPulses.idle { self.tapTimer?.invalidate();self.tapTimer=nil }
                }
            }
            RunLoop.main.add(timer,forMode:.common);tapTimer=timer
        }
    }
    private func hitsSlideTarget(_ c: BCDControlPack.Control, at point: CGPoint) -> Bool {
        guard let target = c.slideToAction else { return false }
        return layout?.controls.contains { candidate in
            candidate.action == target && candidate.role == "button" && (visible(candidate) || (pack.map { BCDTenebrisOwnerCompatibility.hiddenAttack(candidate,in:$0) } ?? false)) &&
                hypot(point.x - center(candidate).x, point.y - center(candidate).y) <= candidate.hitRadius * unit
        } == true
    }
    private func updateSlide(_ finger: inout Finger, at point: CGPoint) {
        guard !finger.slideFired, let c = finger.control, let source = action(c.action),
              source.behavior == "toggle", let targetID = c.slideToAction, let target = action(targetID), target.behavior == "tap" else { return }
        let hit = hitsSlideTarget(c, at: point)
        if !hit { finger.slideArmed = true }
        if hit && finger.slideArmed && hypot(point.x - finger.start.x, point.y - finger.start.y) >= 8 {
            setToggle(source, enabled: true)
            pulse(target); finger.slideFired = true
        }
    }
    private func release(_ owner: UUID) {
        GamepadInput.shared.packTouch(owner: owner, value: nil)
        GamepadInput.shared.packLook(owner: owner, phase: 2, time: ProcessInfo.processInfo.systemUptime)
        if let keys = keyHolds.removeValue(forKey: owner) {
            for key in keys.reversed() where !keyHolds.values.contains(where: { $0.contains(key) }) { winios_post_key(key, 0) }
        }
        if let mouse = mouseHolds.removeValue(forKey: owner), !mouseHolds.values.contains(mouse) {
            winios_pointer(0, 0, mouse == "mouse:left" ? 4 : (mouse == "mouse:right" ? 16 : 64), 0)
        }
    }
    private func send(_ a: BCDControlPack.Action, owner: UUID) {
        guard let p = pack else { return }
        if a.behavior != "toggle", a.output == "Menu" || p.gestures.contains(where: { $0.kind == "tap" && ($0.cancelOn ?? []).contains(a.id) }) { clearToggles() }
        if p.inputMode == "controller" { GamepadInput.shared.packTouch(owner: owner, value: TouchPadAction.sample(a.output)); return }
        if let keys = BCDPackCatalog.keyCodes(a.output) {
            let held = Set(keyHolds.values.flatMap { $0 }); keyHolds[owner] = keys
            for key in keys where !held.contains(key) { winios_post_key(key, 1) }
        } else if ["mouse:left", "mouse:right", "mouse:middle"].contains(a.output) {
            let already = mouseHolds.values.contains(a.output); mouseHolds[owner] = a.output
            if !already { winios_pointer(0, 0, a.output == "mouse:left" ? 2 : (a.output == "mouse:right" ? 8 : 32), 0) }
        } else if a.output.hasPrefix("mouse:wheel") {
            winios_pointer(0, 0, 0x800, UInt32(bitPattern: a.output == "mouse:wheelUp" ? Int32(120) : Int32(-120)))
        } else { GamepadInput.shared.packTouch(owner: owner, value: TouchPadAction.sample(a.output)) }
    }
    private func pulse(_ a: BCDControlPack.Action) {
        let owner = UUID(), generation = epoch
        pulses.insert(owner); pulseActions[owner] = a.id; send(a, owner: owner); setNeedsDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self, self.epoch == generation else { return }
            self.release(owner); self.pulses.remove(owner); self.pulseActions[owner] = nil; self.setNeedsDisplay()
            // Local layout context follows our explicit button, not guessed game state.
            if self.pack?.id.hasPrefix("sulfur") == true {
                let target = a.id == "inventory" ? "inventory" : (a.id == "inventory-close" ? "onFoot" : "")
                if !target.isEmpty,self.pack?.contexts.contains(target) == true {BCDPackStore.shared.context=target}
            }
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let delivery = ProcessInfo.processInfo.systemUptime
        for t in touches { beginTouch(ObjectIdentifier(t), at: t.location(in: self), time: t.timestamp, receivedAt: delivery) }
    }
    func beginTouch(_ identity: AnyHashable, at point: CGPoint, time: Double, receivedAt: Double? = nil) {
        guard UIApplication.shared.applicationState == .active, !LibraryModel.shared.blocksGameplayTouch,
              BCDPackFocus.shared.refresh(), let pack else { clear(); return }
        if let engine=cursorEngine { cursorGeometry();engine.begin(identity,at:point,time:receivedAt ?? time);flushCursor(redraw:true);return }
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
        if !editing, role == "look", pack.lookMode == "none" || (pack.id.hasPrefix("sulfur") && context == "inventory") { role = "ignore" }
        if !editing, role == "button", let c = control, action(c.action)?.behavior == "toggle" { role = "toggle" }
        var finger = Finger(role: role, control: control, start: point, last: point, time: time, began: time)
        if !editing, ["look","ignore","move"].contains(role), (control == nil || control?.role == "move"),
           bounds.contains(point), let g=pack.gestures.first(where: { $0.kind == "tap" }),
           let source=g.whenToggled, action(g.action) != nil, let owner=toggles[source] {
            finger.surfaceTap=BCDPackSurfaceTap(action:g.action,gate:source,gateOwner:owner,start:point,began:time)
        }
        if !editing,control == nil,["look","ignore"].contains(role),point.x >= bounds.midX,
           BCDTenebrisOwnerCompatibility.matches(pack),context == "onFoot",let owner=toggles["raw-lt"] {
            finger.surfaceTap=BCDPackSurfaceTap(action:"raw-rt",gate:"raw-lt",gateOwner:owner,start:point,began:time)
        }
        if role == "toggle", let c = control, let binding = action(c.action) {
            finger.toggleWasOn = toggles[binding.id] != nil
            finger.slideArmed = !hitsSlideTarget(c, at: point)
            setToggle(binding, enabled: true)
        }
        if role == "radial" { finger.radialCenter = radialCenter(at: point) }
        if (role == "look" || role == "fireAim") && pack.lookMode != "relativeMouse" {
            GamepadInput.shared.packLook(owner: finger.owner, phase: 0, time: time, receivedAt: receivedAt)
        }
        if role == "move" { GamepadInput.shared.packTouch(owner: finger.owner, value: TouchPadAction.sample("LS")) }
        if let control, let binding = action(control.action), role == "button" || role == "fireAim" {
            if binding.behavior == "tap" { pulse(binding) }
            else if binding.behavior == "hold" { send(binding, owner: finger.owner) }
        }
        if role == "move",pack.id.hasPrefix("sulfur") {
            _=BCDSulfurSprintBegin(&finger.sulfurSprint,time,BCDPackStore.shared.sulfurSprintAllowed ? 1:0)
        }
        fingers[identity] = finger
        if isQueen && !editing {
            if role == "look" && point.x >= bounds.midX && utilityTouches.isEmpty {
                if let prior=queenFinger,let other=fingers[prior],fingers.count == 2 {
                    let eligible=time >= other.began && time-other.began <= 0.12 && other.queenTravel < 12
                    if eligible && queen.canClaimChord(time:time) && queen.claimChord(time:time) {
                        queenFinger=nil
                        utilityTouches=[prior:(other.start,other.began),identity:(point,time)]
                        utilityEnded=0;utilityInvalid=false
                    } else {queen.cancelPendingUtility()}
                    // A committed charge stays with its original owner. Never
                    // convert it into a menu chord merely because another finger arrives.
                } else if queenFinger == nil {
                    queenFinger=identity
                    queenEvents(queen.begin(at:point,time:time,possibleChord:fingers.count == 1))
                } else {queen.cancelPendingUtility()}
            } else {
                queen.cancelPendingUtility();utilityInvalid=true
                if role != "move" && (role == "radial" || !queen.hasCommittedAttack) {queenEvents(queen.cancelAttack());queenFinger=nil}
            }
        }
        setNeedsDisplay()
    }
    private func observeQueenMotion(_ identity:AnyHashable,at point:CGPoint) {
        guard isQueen else{return}
        guard point.x.isFinite,point.y.isFinite else {utilityInvalid=true;queen.cancelPendingUtility();queenEvents(queen.cancelAttack());return}
        if var f=fingers[identity] {
            f.queenTravel=max(f.queenTravel,hypot(point.x-f.start.x,point.y-f.start.y));fingers[identity]=f
        }
        if queenFinger == identity {queenEvents(queen.move(to:point))}
        if let (start,_)=utilityTouches[identity],hypot(point.x-start.x,point.y-start.y)>12 {utilityInvalid=true;queen.cancelPendingUtility()}
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let delivery = ProcessInfo.processInfo.systemUptime
        for t in touches {
            // Publish one displacement/time interval per delivered batch. Replaying
            // every historical sample made the final sub-sample's tiny interval
            // dictate expiry, even when batches arrived only every 16-33 ms.
            let sample = ((event?.coalescedTouches(for: t) ?? []) + [t]).max { $0.timestamp < $1.timestamp } ?? t
            // Aim keeps batch timing; tap rejection additionally observes the whole
            // coalesced path so a rapid out-and-back drag never becomes an attack.
            for past in event?.coalescedTouches(for:t) ?? [] {
                fingers[ObjectIdentifier(t)]?.surfaceTap?.moved(to:past.location(in:self))
                observeQueenMotion(ObjectIdentifier(t),at:past.location(in:self))
            }
            moveTouch(ObjectIdentifier(t), to: sample.location(in: self), time: sample.timestamp, receivedAt: delivery)
        }
    }
    func moveTouch(_ identity: AnyHashable, to point: CGPoint, time: Double, receivedAt: Double? = nil) {
        guard UIApplication.shared.applicationState == .active, !LibraryModel.shared.blocksGameplayTouch,
              BCDPackFocus.shared.refresh() else { clear(); return }
        if let engine=cursorEngine { cursorGeometry();engine.move(identity,to:point,time:receivedAt ?? time);flushCursor(redraw:true);return }
        guard var finger = fingers[identity], time > finger.time else { return }
        finger.surfaceTap?.moved(to:point)
        observeQueenMotion(identity,at:point)
        finger.queenTravel=max(finger.queenTravel,hypot(point.x-finger.start.x,point.y-finger.start.y))
        if finger.role == "look" || finger.role == "fireAim" {
            if pack?.inputMode == "controller" && pack?.lookMode != "relativeMouse" {
                GamepadInput.shared.packLook(owner: finger.owner, phase: 1, dx: Double(point.x - finger.last.x), dy: Double(point.y - finger.last.y), time: time, receivedAt: receivedAt)
            } else if let calibration = pack?.aim {
                HardwareInput.shared.postRelative(Int32(max(-30000, min(30000, Double(point.x - finger.last.x) * calibration.sensitivity * 2))),
                    Int32(max(-30000, min(30000, Double(point.y - finger.last.y) * calibration.sensitivity * calibration.vertical * 2 * (calibration.invertY ? -1 : 1)))))
            }
        } else if finger.role == "toggle" {
            if hypot(point.x-finger.start.x,point.y-finger.start.y) >= 8 { finger.didDrag = true }
            updateSlide(&finger, at: point)
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
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            for sample in event?.coalescedTouches(for:touch) ?? [] {
                fingers[ObjectIdentifier(touch)]?.surfaceTap?.moved(to:sample.location(in:self))
                observeQueenMotion(ObjectIdentifier(touch),at:sample.location(in:self))
            }
        }
        finish(touches, cancelled: false)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, cancelled: true) }
    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        for t in touches {
            endTouch(ObjectIdentifier(t), at: t.location(in: self), cancelled: cancelled, time:t.timestamp)
        }
    }
    func endTouch(_ identity: AnyHashable, at point: CGPoint, cancelled: Bool, time: Double? = nil) {
            if let engine=cursorEngine {
                if LibraryModel.shared.blocksGameplayTouch || !BCDPackFocus.shared.refresh() { clear();return }
                engine.end(identity,at:point,time:ProcessInfo.processInfo.systemUptime,cancelled:cancelled);flushCursor(redraw:true);return
            }
            if isQueen {finishQueen(identity,point:point,time:time ?? ProcessInfo.processInfo.systemUptime,cancelled:cancelled)}
            guard var f = fingers.removeValue(forKey: identity) else { return }
            release(f.owner)
            defer { setNeedsDisplay() }
            if cancelled {
                if f.role == "toggle", let c = f.control, let a = action(c.action) { setToggle(a, enabled: false) }
                return
            }
            guard !LibraryModel.shared.blocksGameplayTouch, BCDPackFocus.shared.refresh(), let pack else { clear(); return }
            if let tap=f.surfaceTap, tap.recognizes(end:point,time:time ?? ProcessInfo.processInfo.systemUptime,gateOwner:toggles[tap.gate]) {
                if !BCDTenebrisOwnerCompatibility.matches(pack) || max(tap.travel,hypot(point.x-tap.start.x,point.y-tap.start.y)) <= 8 {queueSurfaceTap(tap)}
            }
            if f.role == "toggle", let c = f.control, let a = action(c.action) {
                if hypot(point.x-f.start.x,point.y-f.start.y) >= 8 { f.didDrag = true }
                updateSlide(&f, at: point)
                if f.toggleWasOn && !f.slideFired && !f.didDrag { setToggle(a, enabled: false) }
                return
            }
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
                var edited = pack
                edited.version = max(edited.version, 2)
                let origin = controlCenter(c)
                let destination = CGPoint(x: origin.x + point.x - f.start.x, y: origin.y + point.y - f.start.y)
                func change(_ controls: inout [BCDControlPack.Control]) {
                    if let i = controls.firstIndex(where: { $0.id == c.id }) {
                        controls[i] = positionedControl(c, at: destination)
                    }
                }
                if pad { change(&edited.pad.controls) } else { change(&edited.phone.controls) }
                BCDPackStore.shared.saveEdits(edited)
            }
    }
    override func draw(_ rect: CGRect) {
        guard let layout, let ctx = UIGraphicsGetCurrentContext() else { return }
        cursorGeometry()
        if debug {
            let a = layout.aimRect
            if pack?.lookMode != "none" {
                ctx.setFillColor(UIColor.green.withAlphaComponent(0.1).cgColor)
                ctx.fill(CGRect(x: safe.minX + a.x * safe.width, y: safe.minY + a.y * safe.height, width: a.width * safe.width, height: a.height * safe.height))
            }
            if movementControl != nil {
                ctx.saveGState(); ctx.setStrokeColor(UIColor.cyan.cgColor); ctx.setLineDash(phase: 0, lengths: [5, 4])
                ctx.stroke(movementStartRegion); ctx.restoreGState()
            }
            let status = "Touch roles: " + activeTouchRoles.joined(separator: ", ")
            (status as NSString).draw(at: CGPoint(x: safe.minX + 8, y: safe.minY + 4),
                withAttributes: [.font:UIFont.monospacedSystemFont(ofSize:11, weight:.medium), .foregroundColor:UIColor.cyan])
            if let g=pack?.gestures.first(where: { $0.kind == "tap" }), let gate=g.whenToggled {
                ctx.setStrokeColor(UIColor.orange.cgColor);ctx.stroke(bounds.insetBy(dx:2,dy:2))
                let caption="Tap surface → \(action(g.action)?.label ?? g.action) · requires \(action(gate)?.label ?? gate) · buttons keep ownership"
                (caption as NSString).draw(at:CGPoint(x:safe.minX+8,y:safe.minY+18),withAttributes:[.font:UIFont.systemFont(ofSize:10),.foregroundColor:UIColor.orange])
            }
        }
        for c in layout.controls where visible(c) {
            if let engine=cursorEngine, [.pointer,.paused,.utilities].contains(engine.mode) { continue }
            if cursorEngine?.mode == .equipment && c.role != "move" { continue }
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
                }
                if debug {
                    let h = c.hitRadius * unit
                    ctx.setStrokeColor(UIColor.cyan.cgColor); ctx.strokeEllipse(in: CGRect(x:p.x-h,y:p.y-h,width:h*2,height:h*2))
                }
                continue
            }
            let circle = CGRect(x: p.x-r, y: p.y-r, width: r*2, height: r*2)
            let a = action(c.action)
            let toggled = toggles[c.action] != nil
            let tint = toggled ? UIColor(red:1,green:0.67,blue:0.18,alpha:1) : UIColor.white
            let pressed = fingers.values.contains { $0.control?.id == c.id } || pulseActions.values.contains(c.action) || (tapPulses.down && tapGate?.action == c.action) || cursorEngine?.fingers.values.contains { $0.action == c.action && $0.role != "ignore" } == true
            if pressed { ctx.setFillColor(tint.withAlphaComponent(0.08).cgColor); ctx.fillEllipse(in: circle) }
            ctx.setStrokeColor(tint.withAlphaComponent(toggled || pressed ? 0.95 : c.opacity * ((pack?.version ?? 1) >= 3 ? 0.9 : 0.65)).cgColor)
            ctx.setLineWidth(pressed ? 1.5 : 1); ctx.strokeEllipse(in: circle)
            let icon = c.role == "radial" ? "circle.grid.2x2" : (a?.icon ?? "hand.draw")
            let inside = c.labelPlacement == "inside" && c.showLabel != false
            if let image = BCDPackIcons.image(icon)?.withTintColor(tint.withAlphaComponent(c.opacity), renderingMode: .alwaysOriginal) {
                image.draw(in: CGRect(x: p.x-r*0.42, y: p.y-r*(inside ? 0.65 : 0.42), width: r*0.84, height: r*0.84))
            } else {
                ((a?.output ?? "…") as NSString).draw(at: CGPoint(x:p.x-r*0.5,y:p.y-8),withAttributes:[.font:UIFont.boldSystemFont(ofSize:14),.foregroundColor:UIColor.white])
            }
            let label = (c.role == "radial" ? (pack?.cursorControls != nil ? "Equipment":"Actions") : (a?.label ?? c.role)) + (editing ? " [\(a?.output ?? "") ]" : "")
            if c.showLabel == false && !editing {
                // Icon-only personal control. Its actual hit region remains visible in debug.
            } else if inside && !editing {
                let font = UIFont.systemFont(ofSize: min(18,max(10,r*0.34)))
                let width = (label as NSString).size(withAttributes:[.font:font]).width
                (label as NSString).draw(at:CGPoint(x:p.x-width/2,y:p.y+r*0.28),withAttributes:[.font:font,.foregroundColor:tint.withAlphaComponent(c.opacity)])
            } else {
                (label as NSString).draw(at: CGPoint(x: p.x-r, y: p.y+r+2), withAttributes: [.font:UIFont.systemFont(ofSize: 10), .foregroundColor:tint.withAlphaComponent(c.opacity)])
            }
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
        cursorEngine?.drawOverlay(ctx)
    }
}
