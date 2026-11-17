// Production surfaces; spies replace the engine boundary, never the dispatch.
import Foundation
import UIKit

@MainActor func checkTouchFeedbackDispatch() async throws {
    let identity=BCDControlPack.Identity(executable:"fixture.exe",storeID:"local",edition:"fixture",build:"fixture",bindingDigest:"fixture")
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    func make(_ kind:String)->(BCDControlPack,BCDPackView) {
        let p=BCDTablePack.make(identity,kind:kind)!
        let view=BCDPackView();view.frame=CGRect(x:0,y:0,width:956,height:440)
        view.configure(p,context:"onFoot",debug:false,editing:false);view.layoutIfNeeded()
        return (p,view)
    }
    func reset(){PackBoundarySpy.keys.removeAll();PackBoundarySpy.mouse.removeAll();PackBoundarySpy.pointer.removeAll()}
    func settle() async {try? await Task.sleep(nanoseconds:110_000_000)}
    let (cards,view)=make("inscryption")
    let point=CGPoint(x:450,y:190)
    var now=ProcessInfo.processInfo.systemUptime+1
    reset();view.beginTouch(1,at:point,time:now);view.endTouch(1,at:point,cancelled:false,time:now+0.1)
    assert(PackBoundarySpy.mouse.filter{$0.0==2}.count==1);await settle()
    assert(PackBoundarySpy.mouse.filter{$0.0==4}.count==1)
    reset();now+=1;view.beginTouch(2,at:point,time:now);view.endTouch(2,at:point,cancelled:false,time:now+0.5)
    assert(PackBoundarySpy.mouse.filter{$0.0==8}.count==1 && !PackBoundarySpy.mouse.contains{$0.0==2});await settle()
    assert(PackBoundarySpy.mouse.filter{$0.0==16}.count==1)
    reset();now+=1;view.beginTouch(3,at:point,time:now);view.endTouch(3,at:point,cancelled:true,time:now+0.6);await settle()
    assert(!PackBoundarySpy.mouse.contains{$0.0==8 || $0.0==2})
    reset();now+=1;view.beginTouch(33,at:point,time:now)
    NotificationCenter.default.post(name:BCDPackFocus.didLoseFocus,object:nil)
    view.endTouch(33,at:point,cancelled:false,time:now+0.6);await settle()
    assert(!PackBoundarySpy.mouse.contains{$0.0==8 || $0.0==2},"Focus loss cannot finish a pending hold")
    reset();now+=1;view.beginTouch(4,at:point,time:now);view.moveTouch(4,to:CGPoint(x:480,y:190),time:now+0.5)
    view.endTouch(4,at:CGPoint(x:480,y:190),cancelled:false,time:now+0.7)
    assert(PackBoundarySpy.mouse.filter{$0.0==2}.count==1 && PackBoundarySpy.mouse.contains{$0.0==4})
    assert(!PackBoundarySpy.mouse.contains{$0.0==8})
    // Same arrow controls before and after card selection: no mode switch exists.
    for _ in 0..<2 {
        reset()
        for (index,code) in [87,65,83,68].enumerated() {
            let c=cards.phone.controls[index],p=view.controlCenter(c)
            view.beginTouch(100+index,at:p,time:now);view.endTouch(100+index,at:p,cancelled:false,time:now+0.1)
            assert(PackBoundarySpy.keys.contains{$0.0==Int32(code) && $0.1==1})
            assert(PackBoundarySpy.keys.contains{$0.0==Int32(code) && $0.1==0})
        }
        now+=1;view.beginTouch(5,at:point,time:now);view.endTouch(5,at:point,cancelled:false,time:now+0.1);await settle()
    }
    view.clear()
    let (skald,pad)=make("skald")
    defer {pad.clear();BCDPackStore.shared.skaldUtilitiesVerified=false}
    reset();now+=1;pad.beginTouch(10,at:point,time:now)
    assert(PackBoundarySpy.pointer.isEmpty,"Trackpad touchdown must not warp")
    pad.moveTouch(10,to:CGPoint(x:470,y:200),time:now+0.1);pad.endTouch(10,at:CGPoint(x:470,y:200),cancelled:false,time:now+0.2)
    assert(PackBoundarySpy.pointer.contains{$0.2==1 && $0.0>0 && $0.1>0})
    assert(!PackBoundarySpy.pointer.contains{$0.2 & 0x8000 != 0 || $0.2==2},"Trackpad swipe must not become absolute/drag")
    reset();pad.beginTouch(11,at:CGPoint(x:300,y:100),time:now+1);pad.endTouch(11,at:CGPoint(x:300,y:100),cancelled:true,time:now+1.1)
    assert(!PackBoundarySpy.pointer.contains{$0.2==1},"New contact must retain guest cursor")
    reset();BCDPackStore.shared.skaldUtilitiesVerified=false
    let journal=skald.phone.controls.first{$0.action=="journal"}!,j=pad.controlCenter(journal)
    pad.beginTouch(20,at:j,time:now);pad.endTouch(20,at:j,cancelled:false,time:now+0.1);await settle()
    assert(PackBoundarySpy.keys.isEmpty,"Unverified shipped defaults must be gated")
    BCDPackStore.shared.skaldUtilitiesVerified=true
    for (index,c) in skald.phone.controls.enumerated() {
        reset();let p=pad.controlCenter(c),expected=BCDPackCatalog.keyCodes(skald.actions.first{$0.id==c.action}!.output)!.first!
        pad.beginTouch(30+index,at:p,time:now);pad.endTouch(30+index,at:p,cancelled:false,time:now+0.1);await settle()
        assert(PackBoundarySpy.keys.contains{$0.0==expected && $0.1==1} && PackBoundarySpy.keys.contains{$0.0==expected && $0.1==0})
    }
    var sulfurID=identity;sulfurID.executable="games/sulfur/Sulfur.exe"
    let sulfur=try BCDSulfurPack.make(identity:sulfurID)
    let combat=BCDPackView();combat.frame=CGRect(x:0,y:0,width:956,height:440)
    combat.configure(sulfur,context:"onFoot",debug:false,editing:false);combat.layoutIfNeeded()
    let oldContext=BCDPackStore.shared.context
    for name in ["attack","melee","interact","jump","pause","inventory"] {
        let c=sulfur.phone.controls.first{$0.action==name}!,p=combat.controlCenter(c)
        let a=sulfur.actions.first{$0.id==name}!,expected=TouchPadAction.sample(a.output)
        combat.beginTouch(name,at:p,time:now)
        assert(GamepadInput.shared.sample==expected,"Visible Sulfur button must dispatch its exact native action: \(name)")
        combat.endTouch(name,at:p,cancelled:false,time:now+0.1);await settle()
        assert(GamepadInput.shared.sample==GamepadSample())
    }
    let movement=sulfur.phone.controls.first{$0.role=="move"}!,origin=combat.controlCenter(movement)
    combat.beginTouch("movement",at:origin,time:now)
    combat.moveTouch("movement",to:CGPoint(x:origin.x+40,y:origin.y),time:now+0.1)
    assert(GamepadInput.shared.sample.lx>0)
    combat.endTouch("movement",at:origin,cancelled:true,time:now+0.2);assert(GamepadInput.shared.sample==GamepadSample())
    var sprintFixture=sulfur
    sprintFixture.phone.controls.append(.init(id:"sprint-pulse-fixture",action:"sprint",role:"button",x:0.5,y:0.1,radius:0.04,hitRadius:0.04,opacity:0.4))
    combat.configure(sprintFixture,context:"onFoot",debug:false,editing:false)
    let sprintPoint=combat.controlCenter(sprintFixture.phone.controls.last!)
    combat.beginTouch("sprint-pulse",at:sprintPoint,time:now+0.3)
    assert(GamepadInput.shared.sample.buttons & 0x0040 != 0)
    combat.beginTouch("sprint-move",at:origin,time:now+0.31)
    combat.endTouch("sprint-move",at:origin,cancelled:false,time:now+0.32)
    assert(GamepadInput.shared.sample.buttons & 0x0040 == 0 && GamepadInput.shared.sample.lx==0 && GamepadInput.shared.sample.ly==0)
    combat.endTouch("sprint-pulse",at:sprintPoint,cancelled:false,time:now+0.33)
    combat.configure(sulfur,context:"onFoot",debug:false,editing:false)
    let adsPoint=CGPoint(x:720,y:350)
    func tapADS(_ id:String,_ time:Double) {
        combat.beginTouch(id,at:adsPoint,time:time)
        combat.endTouch(id,at:adsPoint,cancelled:false,time:time+0.04)
    }
    now+=1;tapADS("ads-first",now);assert(GamepadInput.shared.sample.lt==0)
    tapADS("ads-second",now+0.15);assert(GamepadInput.shared.sample.lt==255)
    assert(combat.toggledActionIDs==["aim"])
    // Moving and lifting the left thumb cannot change the right-surface latch.
    combat.beginTouch("move-with-ads",at:origin,time:now+0.3)
    combat.moveTouch("move-with-ads",to:CGPoint(x:origin.x+30,y:origin.y),time:now+0.35)
    combat.endTouch("move-with-ads",at:origin,cancelled:false,time:now+0.4)
    assert(GamepadInput.shared.sample.lt==255)
    tapADS("ads-off-first",now+0.5);tapADS("ads-off-second",now+0.65)
    assert(GamepadInput.shared.sample.lt==0)
    // A camera drag, including an out-and-back path, cannot complete a tap pair.
    tapADS("drag-pair-first",now+1)
    combat.beginTouch("camera-drag",at:adsPoint,time:now+1.15)
    combat.moveTouch("camera-drag",to:CGPoint(x:740,y:350),time:now+1.17)
    combat.moveTouch("camera-drag",to:adsPoint,time:now+1.19)
    combat.endTouch("camera-drag",at:adsPoint,cancelled:false,time:now+1.2)
    assert(GamepadInput.shared.sample.lt==0)
    tapADS("context-first",now+2);tapADS("context-second",now+2.15)
    assert(GamepadInput.shared.sample.lt==255)
    combat.configure(sulfur,context:"inventory",debug:false,editing:false)
    assert(GamepadInput.shared.sample.lt==0 && combat.toggledActionIDs.isEmpty)
    tapADS("inventory-first",now+2.5);tapADS("inventory-second",now+2.65)
    assert(GamepadInput.shared.sample.lt==0)
    combat.configure(sulfur,context:"onFoot",debug:false,editing:false)
    tapADS("focus-first",now+3);tapADS("focus-second",now+3.15)
    NotificationCenter.default.post(name:BCDPackFocus.didLoseFocus,object:nil)
    assert(GamepadInput.shared.sample.lt==0 && combat.toggledActionIDs.isEmpty)
    tapADS("session-first",now+4);tapADS("session-second",now+4.15)
    assert(GamepadInput.shared.sample.lt==255)
    BCDPackStore.shared.activate(nil)
    assert(GamepadInput.shared.sample.lt==0 && combat.toggledActionIDs.isEmpty)
    combat.beginTouch("retired-ads",at:adsPoint,time:now+5)
    combat.endTouch("retired-ads",at:adsPoint,cancelled:false,time:now+5.04)
    assert(GamepadInput.shared.sample.lt==0)
    combat.clear();BCDPackStore.shared.context=oldContext
    // Keep retired views alive: release must be synchronous in the store call,
    // without relying on dismantleUIView, didMoveToWindow or a touch-end event.
    func checkSessionRelease(_ boundary:()->Void) async {
        let (p,retired)=make("inscryption")
        reset()
        let w=retired.controlCenter(p.phone.controls[0]),z=retired.controlCenter(p.phone.controls[4])
        retired.beginTouch("held-w",at:w,time:now)
        retired.beginTouch("pending-z",at:z,time:now)
        retired.endTouch("pending-z",at:z,cancelled:false,time:now+0.01)
        assert(PackBoundarySpy.keys.contains{$0.0==87 && $0.1==1} && PackBoundarySpy.keys.contains{$0.0==90 && $0.1==1})
        boundary()
        assert(PackBoundarySpy.keys.contains{$0.0==87 && $0.1==0} && PackBoundarySpy.keys.contains{$0.0==90 && $0.1==0},"Session boundary must synchronously release held and pulsed keys")
        reset()
        retired.beginTouch("late-down",at:w,time:now+0.02)
        retired.endTouch("held-w",at:w,cancelled:false,time:now+0.03)
        await settle()
        assert(PackBoundarySpy.keys.isEmpty,"Retired view/late pulse callback must not republish keyboard input")
        retired.clear()
    }
    let store=BCDPackStore.shared
    await checkSessionRelease {store.activate(nil)}
    var first=LibraryEntry();first.title="Inscryption session release fixture"
    first.launchRelativePath="fixture-session/Inscryption.exe";first.relativePath=first.launchRelativePath
    store.activate(first)
    let previousEpoch=store.tableInputEpoch
    var next=first;next.id=UUID()
    await checkSessionRelease {store.activate(next)}
    assert(store.tableInputEpoch != previousEpoch,"Same-profile new session must recreate its input view")
    store.activate(nil)
    try Data("PASS: production BCDPackView/BCDTableView delivered left click, hold RMB/release, cancelled/focus-lost hold without click, drag/release, persistent WASD before/after card touch, relative-only trackpad/re-anchor and verified SKALD J/E/Space/Enter/Esc down/up through winios spies. Sulfur visible Attack/Melee/Interact/Pause/Inventory and movement dispatched exact native samples and releases to the UI boundary. activate(nil) and a new session synchronously released held W/pending Z with retired views alive; stale touch/pulse callbacks produced no key events. Simulator fixture; no guest game or phone.".utf8).write(to:folder.appendingPathComponent("touch-feedback-dispatch.txt"))
    // Glyphs use the production UIKit renderer; no text is drawn on these defaults.
    let previews=[("inscryption",cards),("skald",skald),("sulfur",sulfur),("queens-domain",BCDQueensDomainPack.make(identity:identity))]
    for (kind,p) in previews {
        let surface=BCDPackView();surface.frame=CGRect(x:0,y:0,width:956,height:440)
        surface.configure(p,context:"onFoot",debug:false,editing:false);surface.layoutIfNeeded()
        let image=UIGraphicsImageRenderer(size:surface.bounds.size).image {c in
            UIColor(white:0.08,alpha:1).setFill();c.fill(surface.bounds);surface.draw(surface.bounds)
        }
        try image.pngData()!.write(to:folder.appendingPathComponent("feedback-"+kind+"-hud.png"));surface.clear()
    }
}
