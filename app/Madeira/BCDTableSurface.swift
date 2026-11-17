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
    var relative = false, secondaryOnHold = false
    // Opt-in only for Inscryption's former arrow cluster. Outside contacts keep
    // the ordinary pointer owner for their complete lifetime.
    var directionalSwipeRegion:CGRect?
    var directionalSwipe:((Int32)->Void)?
    private struct SwipeContact {
        let identity:AnyHashable
        let start:CGPoint
        let began:Double
        var last:CGPoint
        var travel:CGFloat=0
        var invalid=false
        var state=BCDInscryptionSwipeState()
    }
    private var swipeContact:SwipeContact?
    var sensitivity = 1.0, verticalScale = 1.0
    var inspectOnly = false
    var cancelSequence = 0
    private var cancelPending = false {didSet {BCDTableInputActivity.cancelPending=cancelPending}}
    func explicitCancel() {
        guard canSend else {cancelInput();return}
        guard rightClickCancelsDrag,!cancelPending else {return}
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
    private var primary: AnyHashable?
    private var second: AnyHashable?
    private var contacts=Set<AnyHashable>() {didSet {BCDTableInputActivity.contacts=contacts.count}}
    private var relativeState = BCDTableRelativeState()
    private var previousSize = CGSize.zero
    private var secondStart=CGPoint.zero
    private var chordInvalid=false
    private var pendingSecondary=false
    private var leftDown = false
    private var lastScrollY: CGFloat = 0
    private var epoch = UUID()
    private var tick: Timer?
    func invalidateDirectionalSwipe() {
        guard var swipe=swipeContact else{return}
        swipe.invalid=true;BCDInscryptionSwipeCancel(&swipe.state);swipeContact=swipe
    }
    override init(frame: CGRect) {
        super.init(frame: frame); isMultipleTouchEnabled = true; backgroundColor = .clear
        NotificationCenter.default.addObserver(self, selector: #selector(cancelInput), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(cancelInput), name: BCDPackFocus.didLoseFocus, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit {tick?.invalidate();NotificationCenter.default.removeObserver(self)}
    override func layoutSubviews() {super.layoutSubviews();if previousSize != bounds.size {cancelInput();previousSize=bounds.size}}
    private var canSend: Bool { accepting && UIApplication.shared.applicationState == .active && !LibraryModel.shared.blocksGameplayTouch && BCDPackFocus.shared.refresh() }
    private func position(_ p: CGPoint) {
        guard p.x.isFinite,p.y.isFinite else { return }
        if relative {
            guard bounds.width>0,bounds.height>0 else{return}
            if relativeState.active == 0 {BCDTableRelativeBegin(&relativeState,Double(p.x),Double(p.y));return}
            var width:Int32=0,height:Int32=0;winios_screen_size(&width,&height)
            let scaleX=Double(max(1,width))/Double(bounds.width)*sensitivity
            let scaleY=Double(max(1,height))/Double(bounds.height)*sensitivity*verticalScale
            if BCDTableRelativeMove(&relativeState,Double(p.x),Double(p.y),scaleX,scaleY) != 0 {
                HardwareInput.shared.postCursorPackRelative(relativeState.dx,relativeState.dy)
            }
            return
        }
        guard let target = MetalBackedView.keyboardTarget else{return}
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
        primary=nil;second=nil;swipeContact=nil;contacts.removeAll();pendingSecondary=false;chordInvalid=false;policy=BCDTableTouchState()
        relativeState=BCDTableRelativeState()
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        for touch in touches.sorted(by:{$0.timestamp<$1.timestamp}) {
            beginContact(ObjectIdentifier(touch),at:touch.location(in:self),time:touch.timestamp)
        }
    }
    /// Also used by the editable pack surface; UIKit and synthetic delivery
    /// fixtures exercise the same ownership and winios dispatch functions.
    func beginContact(_ identity:AnyHashable,at p:CGPoint,time:Double) {
        if cancelPending {return}
        guard canSend,p.x.isFinite,p.y.isFinite,time.isFinite else {cancelInput();return}
        guard !contacts.contains(identity) else{return}
        let wasEmpty=contacts.isEmpty
        contacts.insert(identity)
        if wasEmpty,let region=directionalSwipeRegion,region.contains(p),directionalSwipe != nil {
            var swipe=SwipeContact(identity:identity,start:p,began:time,last:p)
            BCDInscryptionSwipeBegin(&swipe.state,Double(p.x),Double(p.y),time)
            swipeContact=swipe
            return
        }
        if let swipe=swipeContact {
            // A second pointer contact restores the established two-finger
            // click/scroll policy. Never turn a moved swipe into a card drag.
            swipeContact=nil;beginPointer(swipe.identity,at:swipe.start,time:swipe.began)
            if swipe.invalid || swipe.travel>8 {policy.moved=1}
        }
        if wasEmpty {
            beginPointer(identity,at:p,time:time)
        } else if second == nil && primary != nil && policy.multi == 0 {
            second=identity;secondStart=p;lastScrollY=secondStart.y
            if time-policy.began > 0.12 {chordInvalid=true;policy.moved=1}
            if BCDTableSecond(&policy) != 0 {
                policy.moved=1;chordInvalid=true
                if rightClickCancelsDrag {explicitCancel();return}
                // No cancellation claim for other games: retain the user's
                // existing drag until its owning finger actually releases.
            }
        } else { policy.moved=1;chordInvalid=true;pendingSecondary=false }
    }
    private func beginPointer(_ identity:AnyHashable,at p:CGPoint,time:Double) {
        pendingSecondary=false;chordInvalid=false
        primary=identity;relativeState=BCDTableRelativeState();position(p)
        BCDTableBegin(&policy,Double(p.x),Double(p.y),time)
        if inspectOnly {policy.inspect=1}
        let clock=Timer(timeInterval:0.03,repeats:true) { [weak self] _ in
            guard let self else{return};if !self.canSend {self.cancelInput();return}
            _=BCDTableTick(&self.policy,ProcessInfo.processInfo.systemUptime)
        }
        RunLoop.main.add(clock,forMode:.common);tick=clock
    }
    func moveContact(_ identity:AnyHashable,to p:CGPoint,allowBeginDrag:Bool=true) {
        guard canSend,p.x.isFinite,p.y.isFinite else{cancelInput();return}
        if var swipe=swipeContact,swipe.identity == identity {
            swipe.last=p;swipe.travel=max(swipe.travel,hypot(p.x-swipe.start.x,p.y-swipe.start.y))
            if directionalSwipeRegion?.contains(p) != true {swipe.invalid=true;BCDInscryptionSwipeCancel(&swipe.state)}
            BCDInscryptionSwipeMove(&swipe.state,Double(p.x),Double(p.y));swipeContact=swipe;return
        }
        if identity == second {
            BCDTableSecondMove(&policy,Double(secondStart.x),Double(secondStart.y),Double(p.x),Double(p.y))
            if hypot(p.x-secondStart.x,p.y-secondStart.y)>10 {chordInvalid=true;pendingSecondary=false}
            let delta=p.y-lastScrollY
            if abs(delta)>18 {policy.moved=1;lastScrollY=p.y;winios_pointer(0,0,0x800,UInt32(bitPattern:delta>0 ? -120:120))}
        } else if identity == primary {
            let action=BCDTableHoldMove(&policy,Double(p.x),Double(p.y),secondaryOnHold ? 1:0);position(p)
            if allowBeginDrag && action & Int32(BCD_TABLE_DOWN) != 0 && allowDrag {winios_pointer(0,0,2,0);leftDown=true}
        }
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard canSend else {cancelInput();return}
        for touch in touches {
            for sample in event?.coalescedTouches(for:touch) ?? [] {moveContact(ObjectIdentifier(touch),to:sample.location(in:self))}
            moveContact(ObjectIdentifier(touch),to:touch.location(in:self))
        }
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard canSend else {cancelInput();return}
        // Observe ALL final/coalesced coordinates before committing any click.
        for touch in touches {
            for sample in event?.coalescedTouches(for:touch) ?? [] {moveContact(ObjectIdentifier(touch),to:sample.location(in:self),allowBeginDrag:false)}
            moveContact(ObjectIdentifier(touch),to:touch.location(in:self),allowBeginDrag:false)
        }
        for touch in touches {endContact(ObjectIdentifier(touch),at:touch.location(in:self),time:touch.timestamp)}
    }
    func endContact(_ identity:AnyHashable,at end:CGPoint,time:Double,cancelled:Bool=false) {
        guard canSend,!cancelled else{cancelInput();return}
        moveContact(identity,to:end,allowBeginDrag:false)
        if var swipe=swipeContact,swipe.identity == identity {
            swipeContact=nil
            let decision=BCDInscryptionSwipeEnd(&swipe.state,Double(end.x),Double(end.y),time,swipe.invalid ? 1:0)
            if decision == Int32(BCDInscryptionSwipePointer) {
                // Replay only a stationary pointer gesture, with its real age so
                // the existing tap/hold policy remains intact. No early click.
                beginPointer(identity,at:swipe.start,time:swipe.began)
                endContact(identity,at:end,time:time);return
            }
            contacts.remove(identity)
            if decision != Int32(BCDInscryptionSwipeNone) {directionalSwipe?(decision)}
            return
        }
        if identity == primary {
            let action=BCDTableHoldEnd(&policy,Double(end.x),Double(end.y),time,chordInvalid ? 1:0,secondaryOnHold ? 1:0)
            if leftDown {winios_pointer(0,0,4,0);leftDown=false}
            if action & Int32(BCD_TABLE_CLICK) != 0 {click(false)}
            pendingSecondary = !inspectOnly && action & Int32(BCD_TABLE_SECONDARY) != 0
            primary=nil;tick?.invalidate();tick=nil
        }
        if identity == second {
            if time-policy.began>0.35 {chordInvalid=true;pendingSecondary=false}
            second=nil
        }
        contacts.remove(identity)
        if contacts.isEmpty {
            if pendingSecondary && !chordInvalid {click(true)}
            pendingSecondary=false;second=nil;relativeState=BCDTableRelativeState()
        }
    }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) {cancelInput()}
}

/// Utility rail owns only its buttons; the remaining screen remains direct touch.
struct BCDTableUtilityRail: View {
    @ObservedObject private var store = BCDPackStore.shared
    var body: some View {
        VStack(spacing:14) {
            if store.tableSurface == "spire2" {
                Button {
                    if BCDTableInputActivity.cancelPending {return}
                    if store.spireUtilitiesVerified && !BCDTableInputActivity.busy {BCDTablePad.shared.pulse(BCDTableCancel)}
                    else {store.tableCancelSequence += 1}
                } label: {Label("Cancel",systemImage:"xmark")}
                if store.spireUtilitiesVerified {Button {BCDTablePad.shared.pulse(BCDTableMap)} label: {Label("Map",systemImage:"map")}}
            }
        }.font(.caption).buttonStyle(.bordered).padding(6)
            .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:14))
    }
}

@MainActor enum BCDTableInputActivity {
    static var contacts=0
    static var cancelPending=false
    // Cancellation owns the mouse through its ordered right-press/left-release interval.
    static var busy:Bool {contacts != 0 || cancelPending}
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
              !LibraryModel.shared.blocksGameplayTouch,!BCDTableInputActivity.busy,
              UIApplication.shared.applicationState == .active,BCDPackFocus.shared.refresh() else{return}
        // Public build: owner-approved removal of redundant literal-checksum
        // lookup. Existing verified title/session/focus gates above remain.
        let mask: UInt16 = skald
            ? (utility == BCDTableSelect ? 0x1000 : utility == BCDTableCancel ? 0x2000 : utility == BCDTableJournal ? 0x0010 : 0)
            : (utility == BCDTableCancel ? 0x2000 : utility == BCDTableMap ? 0x0020 : 0)
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
