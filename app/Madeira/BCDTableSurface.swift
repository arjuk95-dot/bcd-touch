// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import UIKit

/// Direct pointer surface for verified mouse-driven games. Context is explicitly
/// selected by the player; no guessed screen/image or game-state detection.
struct BCDTableSurface: UIViewRepresentable {
    var accepting: Bool
    var rightClickCancelsDrag = false
    var allowDrag = true
    var inspectOnly = false
    var cancelSequence = 0
    func makeUIView(context: Context) -> BCDTableView { BCDTableView() }
    func updateUIView(_ view: BCDTableView, context: Context) {
        view.rightClickCancelsDrag = rightClickCancelsDrag; view.allowDrag = allowDrag
        if view.inspectOnly != inspectOnly {view.cancelInput();view.inspectOnly=inspectOnly}
        if view.cancelSequence != cancelSequence {view.cancelSequence=cancelSequence;view.explicitCancel()}
        if view.accepting != accepting { view.cancelInput(); view.accepting = accepting }
    }
    static func dismantleUIView(_ view: BCDTableView, coordinator: ()) { view.cancelInput() }
}
final class BCDTableView: UIView {
    var accepting = false, rightClickCancelsDrag = false, allowDrag = true
    var inspectOnly = false
    var cancelSequence = 0
    private var cancelPending = false
    func explicitCancel() {
        guard canSend else {cancelInput();return}
        guard rightClickCancelsDrag else {return}
        let id=epoch
        cancelPending=true;tick?.invalidate();tick=nil;primary=nil;second=nil;contacts.removeAll();pendingSecondary=false;chordInvalid=false;policy=BCDTableTouchState()
        // Keep Cancel observable for a delivery interval before releasing drag.
        winios_pointer(0,0,8,0)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.08) {[weak self] in
            guard let self,self.epoch == id else{return}
            winios_pointer(0,0,4,0);winios_pointer(0,0,16,0)
            self.leftDown=false;self.cancelPending=false
        }
    }
    private var policy = BCDTableTouchState()
    private var primary: UITouch?
    private var second: UITouch?
    private var contacts=Set<ObjectIdentifier>() {didSet {BCDTableInputActivity.contacts=contacts.count}}
    private var secondStart=CGPoint.zero
    private var chordInvalid=false
    private var pendingSecondary=false
    private var leftDown = false
    private var lastScrollY: CGFloat = 0
    private var epoch = UUID()
    private var tick: Timer?
    override init(frame: CGRect) {
        super.init(frame: frame); isMultipleTouchEnabled = true; backgroundColor = .clear
        NotificationCenter.default.addObserver(self, selector: #selector(cancelInput), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelInput), name: BCDPackFocus.didLoseFocus, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit {tick?.invalidate();NotificationCenter.default.removeObserver(self)}
    private var canSend: Bool { accepting && UIApplication.shared.applicationState == .active && !LibraryModel.shared.blocksGameplayTouch && BCDPackFocus.shared.refresh() }
    private func position(_ p: CGPoint) {
        guard p.x.isFinite,p.y.isFinite,let target = MetalBackedView.keyboardTarget else { return }
        let (x,y) = target.mapPoint(convert(p, to: target))
        winios_pointer(x,y,0x8001,0); winios_cursor_move(x,y)
    }
    private func click(_ right: Bool) {
        let id = epoch
        winios_pointer(0,0,right ? 8:2,0)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.08) { [weak self] in
            guard let self, self.epoch == id else { return }
            winios_pointer(0,0,right ? 16:4,0)
        }
    }
    private func cancelDrag() {
        if leftDown && rightClickCancelsDrag { winios_pointer(0,0,8,0) }
        if leftDown { winios_pointer(0,0,4,0);leftDown=false }
        if rightClickCancelsDrag { winios_pointer(0,0,16,0) }
    }
    @objc func cancelInput() {
        epoch=UUID();cancelPending=false;tick?.invalidate();tick=nil;cancelDrag()
        // Release even an in-flight tap pulse when context/focus disappears.
        winios_pointer(0,0,4|16,0)
        primary=nil;second=nil;contacts.removeAll();pendingSecondary=false;chordInvalid=false;policy=BCDTableTouchState()
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        if cancelPending {return}
        guard canSend else { cancelInput();return }
        for touch in touches.sorted(by:{$0.timestamp<$1.timestamp}) {
            let wasEmpty=contacts.isEmpty
            contacts.insert(ObjectIdentifier(touch))
            if wasEmpty {
                pendingSecondary=false;chordInvalid=false

                primary=touch;let p=touch.location(in:self);position(p)
                BCDTableBegin(&policy,Double(p.x),Double(p.y),touch.timestamp)
                if inspectOnly {policy.inspect=1}
                tick=Timer.scheduledTimer(withTimeInterval:0.03,repeats:true) { [weak self] _ in
                    guard let self else{return};if !self.canSend {self.cancelInput();return}
                    _=BCDTableTick(&self.policy,ProcessInfo.processInfo.systemUptime)
                }
            } else if second == nil && primary != nil && policy.multi == 0 {
                second=touch;secondStart=touch.location(in:self);lastScrollY=secondStart.y
                if touch.timestamp-policy.began > 0.12 {chordInvalid=true;policy.moved=1}
                if BCDTableSecond(&policy) != 0 {
                    policy.moved=1;chordInvalid=true
                    if rightClickCancelsDrag {explicitCancel();return}
                    // No cancellation claim for other games: retain the user's
                    // existing drag until its owning finger actually releases.
                }
            } else { policy.moved=1;chordInvalid=true;pendingSecondary=false }
        }
    }
    private func observe(_ touch:UITouch,point p:CGPoint,allowBeginDrag:Bool) {
        if touch === second {
            BCDTableSecondMove(&policy,Double(secondStart.x),Double(secondStart.y),Double(p.x),Double(p.y))
            if hypot(p.x-secondStart.x,p.y-secondStart.y)>10 {chordInvalid=true;pendingSecondary=false}
            let delta=p.y-lastScrollY
            if abs(delta)>18 {policy.moved=1;lastScrollY=p.y;winios_pointer(0,0,0x800,UInt32(bitPattern:delta>0 ? -120:120))}
        } else if touch === primary {
            let action=BCDTableMove(&policy,Double(p.x),Double(p.y));position(p)
            if allowBeginDrag && action & Int32(BCD_TABLE_DOWN) != 0 && allowDrag {winios_pointer(0,0,2,0);leftDown=true}
        }
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard canSend else {cancelInput();return}
        for touch in touches {
            for sample in event?.coalescedTouches(for:touch) ?? [] {observe(touch,point:sample.location(in:self),allowBeginDrag:true)}
            observe(touch,point:touch.location(in:self),allowBeginDrag:true)
        }
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard canSend else {cancelInput();return}
        // Observe ALL final/coalesced coordinates before committing any click.
        for touch in touches {
            for sample in event?.coalescedTouches(for:touch) ?? [] {observe(touch,point:sample.location(in:self),allowBeginDrag:false)}
            observe(touch,point:touch.location(in:self),allowBeginDrag:false)
        }
        if let p=primary,touches.contains(p) {
            let end=p.location(in:self)
            let action=BCDTableEndAt(&policy,Double(end.x),Double(end.y),p.timestamp,chordInvalid ? 1:0)
            if leftDown {winios_pointer(0,0,4,0);leftDown=false}
            if action & Int32(BCD_TABLE_CLICK) != 0 {click(false)}
            pendingSecondary = !inspectOnly && action & Int32(BCD_TABLE_SECONDARY) != 0
            primary=nil;tick?.invalidate();tick=nil
        }
        if let s=second,touches.contains(s) {
            if s.timestamp-policy.began>0.35 {chordInvalid=true;pendingSecondary=false}
            second=nil
        }
        for touch in touches {contacts.remove(ObjectIdentifier(touch))}
        if contacts.isEmpty {
            if pendingSecondary && !chordInvalid {click(true)}
            pendingSecondary=false;second=nil
        }
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) {cancelInput()}
}

/// Utility rail owns only its buttons; the remaining screen remains direct touch.
struct BCDTableUtilityRail: View {
    @ObservedObject private var store = BCDPackStore.shared
    var body: some View {
        VStack(spacing:14) {
            if store.tableSurface == "inscryption" {
                Button {store.switchInscryptionMode()} label: {
                    Label(store.inscryptionExplore ? "Cards":"Explore",systemImage:store.inscryptionExplore ? "rectangle.on.rectangle":"figure.walk")
                }.contextMenu {
                    Button("Cards layout only") {store.resyncInscryption(explore:false)}
                    Button("Explore layout only") {store.resyncInscryption(explore:true)}
                }
            }
            Button {store.tableInspectOnly.toggle()} label: {
                Label(store.tableInspectOnly ? "Inspect on":"Inspect",systemImage:"magnifyingglass")
            }.tint(store.tableInspectOnly ? .orange:.white)
            if store.tableSurface == "skald" && store.skaldUtilitiesVerified {
                Button {BCDTablePad.shared.pulse(BCDTableSelect)} label: {Label("Interact",systemImage:"hand.tap")}
                Button {BCDTablePad.shared.pulse(BCDTableCancel)} label: {Label("Back",systemImage:"arrow.uturn.backward")}
                Button {BCDTablePad.shared.pulse(BCDTableJournal)} label: {Label("Journal",systemImage:"book")}
            }
            if store.tableSurface == "spire2" {
                Button {
                    if store.spireUtilitiesVerified && BCDTableInputActivity.contacts == 0 {BCDTablePad.shared.pulse(BCDTableCancel)}
                    else {store.tableCancelSequence += 1}
                } label: {Label("Cancel",systemImage:"xmark")}
                if store.spireUtilitiesVerified {Button {BCDTablePad.shared.pulse(BCDTableMap)} label: {Label("Map",systemImage:"map")}}
            }
        }.font(.caption).buttonStyle(.bordered).padding(6)
            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14))
    }
}

@MainActor enum BCDTableInputActivity { static var contacts=0 }

/// Inscryption's separately approved PC keyboard route. Independent owner counts
/// prevent a pulse release from releasing another held touch on the same key.
@MainActor final class BCDTableKeys:NSObject {
    static let shared=BCDTableKeys()
    private var owners:[UUID:Int32]=[:]
    private var pulses=Set<UUID>()
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,selector:#selector(releaseAll),name:UIApplication.willResignActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(releaseAll),name:BCDPackFocus.didLoseFocus,object:nil)
    }
    private var accepting:Bool {
        let store=BCDPackStore.shared
        return store.enabled && store.tableSurface == "inscryption" && UIApplication.shared.applicationState == .active && !LibraryModel.shared.blocksGameplayTouch && BCDPackFocus.shared.refresh()
    }
    func press(_ key:Int32,owner:UUID) {
        guard accepting,[65,68,83,87,90].contains(key),owners[owner] != key else{return}
        release(owner)
        let held=owners.values.contains(key);owners[owner]=key
        if !held {winios_post_key(key,1)}
    }
    func release(_ owner:UUID) {
        guard let key=owners.removeValue(forKey:owner) else{return}
        if !owners.values.contains(key) {winios_post_key(key,0)}
    }
    func pulse(_ key:Int32) {
        let owner=UUID();pulses.insert(owner);press(key,owner:owner)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.08) {[weak self] in
            self?.release(owner);self?.pulses.remove(owner)
        }
    }
    func releaseHeldControls() {for owner in Array(owners.keys) where !pulses.contains(owner) {release(owner)}}
    @objc func releaseAll() {for owner in Array(owners.keys) {release(owner)};pulses.removeAll()}
}

private struct BCDInscryptionKey: UIViewRepresentable {
    let key:Int32
    let accepting:Bool
    func makeUIView(context:Context)->BCDInscryptionKeyView {BCDInscryptionKeyView()}
    func updateUIView(_ view:BCDInscryptionKeyView,context:Context) {view.configure(key:key,accepting:accepting)}
    static func dismantleUIView(_ view:BCDInscryptionKeyView,coordinator:()) {view.release()}
}
private final class BCDInscryptionKeyView:UIView {
    private var lastSize=CGSize.zero
    override func layoutSubviews() {super.layoutSubviews();if lastSize != bounds.size {release();lastSize=bounds.size}}
    private var key:Int32=0
    private var accepting=false
    private let owner=UUID()
    private var touches=Set<ObjectIdentifier>()
    override init(frame:CGRect) {super.init(frame:frame);isMultipleTouchEnabled=true;backgroundColor = .clear}
    required init?(coder:NSCoder) {fatalError()}
    func configure(key:Int32,accepting:Bool) {if self.key != key || !accepting {release()};self.key=key;self.accepting=accepting}
    func release() {touches.removeAll();BCDTableKeys.shared.release(owner)}
    override func didMoveToWindow() {super.didMoveToWindow();if window == nil {release()}}
    override func touchesBegan(_ incoming:Set<UITouch>,with event:UIEvent?) {
        guard accepting else{return}
        for touch in incoming {touches.insert(ObjectIdentifier(touch))}
        BCDTableKeys.shared.press(key,owner:owner)
    }
    override func touchesEnded(_ incoming:Set<UITouch>,with event:UIEvent?) {
        for touch in incoming {touches.remove(ObjectIdentifier(touch))}
        if touches.isEmpty {release()}
    }
    override func touchesCancelled(_ incoming:Set<UITouch>,with event:UIEvent?) {release()}
}
struct BCDInscryptionExploreControls:View {
    var accepting:Bool
    private func key(_ code:Int32,_ symbol:String,_ label:String,size:CGFloat=58)->some View {
        Image(systemName:symbol).font(.title2).foregroundStyle(.white)
            .frame(width:size,height:size).background(.black.opacity(0.3),in:Circle())
            .overlay(BCDInscryptionKey(key:code,accepting:accepting)).accessibilityLabel(label)
    }
    var body:some View {
        HStack {
            VStack(spacing:8) {
                key(87,"arrow.up","Step forward")
                HStack(spacing:8) {key(65,"arrow.turn.up.left","Turn left");key(83,"arrow.down","Step back");key(68,"arrow.turn.up.right","Turn right")}
            }.padding(.leading,20).padding(.bottom,24)
            Spacer()
            key(90,"hand.tap","Interact",size:72).padding(.trailing,120).padding(.bottom,130)
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.bottom)
    }
}

@MainActor final class BCDTablePad:NSObject {
    static let shared=BCDTablePad()
    private var owners=Set<UUID>()
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,selector:#selector(cancel),name:UIApplication.willResignActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(cancel),name:BCDPackFocus.didLoseFocus,object:nil)
    }
    func pulse(_ utility:BCDTableNativeUtility) {
        let store=BCDPackStore.shared
        let skald=store.tableSurface == "skald"
        let verified=skald ? store.skaldUtilitiesVerified : (store.tableSurface == "spire2" && store.spireUtilitiesVerified)
        guard store.enabled,verified,
              !LibraryModel.shared.blocksGameplayTouch,BCDTableInputActivity.contacts == 0,
              UIApplication.shared.applicationState == .active,BCDPackFocus.shared.refresh() else{return}
        let mask=BCDTableNativeButton(skald ? BCDTableSkald:BCDTableSTS2,utility,
            skald ? "a9929c9e7e7f06829692ae7c23df2c147d64ea050bdf18649adbd44e1fbcd075":"0861bfa1df347538d932f22d580e75420f08082792eb914e53b4882764acdbe9",
            skald ? "faca117d2bcfacc1ea980de701253fff20b8c7fb93e01b7033a1f3820697f6a8":"88bc2e4f6a2627204b20a714cb8746a269c009e48255dcfc7a0eaef9503d2227",0)
        guard mask != 0 else{return}
        let owner=UUID();owners.insert(owner)
        GamepadInput.shared.configurePack(enabled:true,accepting:true,calibration:BCDMouseJoystick.Calibration())
        var sample=GamepadSample();sample.buttons=mask
        GamepadInput.shared.packTouch(owner:owner,value:sample)
        DispatchQueue.main.asyncAfter(deadline:.now()+0.08) {[weak self] in
            GamepadInput.shared.packTouch(owner:owner,value:nil);self?.owners.remove(owner)
        }
    }
    @objc func cancel() {for owner in owners {GamepadInput.shared.packTouch(owner:owner,value:nil)};owners.removeAll()}
}
