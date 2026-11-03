// Simulator-only harness. Production renderer, engine stubs, no guest game.
import SwiftUI
import UIKit
@main struct TouchPackPreview: App {
    let pack: BCDControlPack = try! BCDControlPack.decode(Data(contentsOf: Bundle.main.url(forResource:"pack",withExtension:"json")!))
    var body: some Scene {
        WindowGroup {
            ZStack(alignment:.top) {
                Color(red:0.06,green:0.08,blue:0.09)
                BCDPackSurface(pack:pack,context:pack.contexts[0],debug:ProcessInfo.processInfo.environment["PACK_DEBUG"] == "1",editing:false)
                VStack {
                    Text("SIMULATOR HUD PREVIEW · NO GAME").font(.caption.bold())
                    Text(pack.title + " · binding meanings unresolved").font(.caption2)
                }.foregroundStyle(.white).allowsHitTesting(false).padding(.top,8)
            }.ignoresSafeArea().statusBarHidden().onAppear {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue,forKey:"orientation")
                if ProcessInfo.processInfo.environment["PACK_FIXTURES"] == "1" {
                    captureFixtures()
                    Task { @MainActor in
                        do { try await checkStoreClient() }
                        catch {
                            let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
                            try? Data(String(describing:error).utf8).write(to:folder.appendingPathComponent("client-error.txt"))
                            assertionFailure("Production store client fixture failed: \(error)")
                        }
                    }
                }
            }
        }
    }
    @MainActor private func captureFixtures() {
        let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        for title in ["dread-delusion","chronicles-of-the-wolf","dread-delusion-installed-iphone"] {
            guard let url=Bundle.main.url(forResource:title,withExtension:"json"), let data=try? Data(contentsOf:url), let original=try? BCDControlPack.decode(data) else { continue }
            let expected = ["steam:1574240":"b2c8962db5b66d02870857cbc88678f5bc0f7e2357445534b137f349aeada2c8", "steam:2371890":"e055f885bade4adf937e0229ee017112a040cebef41b3f6202d0039a49115a65"]
            let key = BCDPackStore.hash(BCDPackStore.encoded(original.identity))
            let expectedKey = title == "dread-delusion-installed-iphone" ? "9a4ca6de6139b1c63ec99e71503f12ee4047f0853fbe4411576580a97dce4902" : expected[original.identity.storeID]
            assert(key == expectedKey, "Swift/worker identity hash mismatch")
            try? Data(key.utf8).write(to:folder.appendingPathComponent(title+"-swift-identity.txt"))
            for isPad in [false,true] {
                let size=isPad ? CGSize(width:1194,height:834) : CGSize(width:956,height:440)
                let insets=isPad ? UIEdgeInsets(top:24,left:0,bottom:20,right:0) : UIEdgeInsets(top:0,left:62,bottom:21,right:62)
                var p=original
                if isPad { p.phone=p.pad }
                for debug in [false,true] {
                    let view=BCDPackView();view.frame=CGRect(origin:.zero,size:CGSize(width:size.width-insets.left-insets.right,height:size.height-insets.top-insets.bottom))
                    view.configure(p,context:p.contexts[0],debug:debug,editing:false)
                    let format=UIGraphicsImageRendererFormat();format.scale=isPad ? 2 : 3;format.opaque=true
                    let image=UIGraphicsImageRenderer(size:size,format:format).image { context in
                        UIColor(red:0.06,green:0.08,blue:0.09,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size))
                        context.cgContext.saveGState();context.cgContext.translateBy(x:insets.left,y:insets.top)
                        view.draw(view.bounds);context.cgContext.restoreGState()
                        let label="SIMULATOR RENDERER FIXTURE · \(isPad ? "iPad geometry" : "phone geometry") · NO GAME"
                        (label as NSString).draw(at:CGPoint(x:size.width*0.27,y:5),withAttributes:[.font:UIFont.systemFont(ofSize:10),.foregroundColor:UIColor.white])
                    }
                    let name=title+"-"+(isPad ? "pad" : "phone")+"-"+(debug ? "hits" : "hud")+".png"
                    try? image.pngData()?.write(to:folder.appendingPathComponent(name))
                }
                // Unsupported context must leave no button, radial or gesture drawing.
                // Acquisition uses the same visibility predicate, avoiding invisible blockers.
                let hidden=BCDPackView();hidden.frame=CGRect(x:0,y:0,width:320,height:180)
                hidden.configure(p,context:"unsupported-context-fixture",debug:false,editing:false)
                let transparent=UIGraphicsImageRendererFormat();transparent.scale=1;transparent.opaque=false
                let empty=UIGraphicsImageRenderer(size:hidden.bounds.size,format:transparent).image { _ in hidden.draw(hidden.bounds) }
                let pixels=empty.cgImage!.dataProvider!.data! as Data
                assert(pixels.allSatisfy { $0 == 0 }, "Inactive context has visible controls")
            }
            try? Data("PASS: inactive context hides all acquisition regions, radial and gesture controls".utf8).write(to:folder.appendingPathComponent(title+"-context-visibility.txt"))
        }
    }
    @MainActor private func checkStoreClient() async throws {
        let original=try BCDControlPack.decode(Data(contentsOf:Bundle.main.url(forResource:"dread-delusion",withExtension:"json")!))
        var entry=LibraryEntry();entry.title="Dread Delusion";entry.steamAppID=1574240
        entry.launchRelativePath=original.identity.executable;entry.relativePath=original.identity.executable
        let store=BCDPackStore.shared, folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let req=store.request(entry)
        assert(req.identity==original.identity)
        let key=BCDPackStore.hash(BCDPackStore.encoded(req.identity))
        let cached=store.folder.appendingPathComponent(key+".json")
        let index=original.phone.controls.firstIndex { $0.role=="move" }!
        let movedX=0.13
        if ProcessInfo.processInfo.environment["PACK_CLIENT_RESUME"]=="1" {
            store.applyLaunchPreference(entry)
            guard !store.enabled else { throw NSError(domain:"TouchFixture",code:1,userInfo:[NSLocalizedDescriptionKey:"Per-game stock input preference was not off at restart"]) }
            store.activate(entry)
            assert(store.pack?.phone.controls[index].x==movedX, "Personal edit lost after process restart")
            let restored = store.pack!.phone.controls.last!
            assert(restored.action == "rt" && restored.coordinateSpace == "screen" && restored.x == 0.5 && restored.y == 0.5, "Personal overlap/full-screen anchor/order lost after restart")
            assert(store.pack!.phone.controls.filter { $0.coordinateSpace == "screen" && $0.x == 0.5 && $0.y == 0.5 }.count >= 2)
            assert(store.pack?.actions.contains { $0.label == "Player action fixture" && $0.icon == "shield" && $0.output == "RB" } == true, "Personal binding/icon/label lost after process restart")
            assert(store.pack?.title==original.title+" fixture regeneration", "Wrong cached pack after restart")
            store.setLaunchPreference(entry,generated:true);store.applyLaunchPreference(entry)
            assert(store.enabled)
            try Data("PASS: fresh simulator app process restored generated cache, personal override and per-game stock input preference; reselecting generated controls succeeds. Engine boundaries stubbed, no installed game".utf8).write(to:folder.appendingPathComponent("client-phase-2.txt"),options:.atomic)
            return
        }
        try BCDPackStore.encoded(original).write(to:cached,options:.atomic)
        store.prepare(entry);store.prepare(entry)
        assert(store.status=="Validated cached pack")
        store.activate(entry)
        try await Task.sleep(nanoseconds:200_000_000)
        try checkWindowRouting(original)
        try await checkPackInteractions(original)
        try await captureEditorFixtures()
        try captureAuthoringFixtures()
        var moved=store.pack!;moved.phone.controls[index].x=movedX
        moved.version = 2
        let editedAction=moved.actions.firstIndex { $0.output=="RT" }!
        moved.actions[editedAction].label="Player action fixture";moved.actions[editedAction].icon="shield";moved.actions[editedAction].output="RB"
        for i in moved.phone.controls.indices where ["rt", "a"].contains(moved.phone.controls[i].action) {
            moved.phone.controls[i].coordinateSpace = "screen"; moved.phone.controls[i].x = 0.5; moved.phone.controls[i].y = 0.5
        }
        let front = moved.phone.controls.remove(at: moved.phone.controls.firstIndex { $0.action == "rt" }!)
        moved.phone.controls.append(front)
        assert(store.saveEdits(moved))
        var temporary=moved;temporary.aim.sensitivity=3;assert(store.saveEdits(temporary));store.undoEdit()
        assert(store.pack?.aim==moved.aim,"Undo failed")
        var regenerated=original;regenerated.title += " fixture regeneration"
        try BCDPackStore.encoded(regenerated).write(to:cached,options:.atomic)
        store.setLaunchPreference(entry,generated:false)
        LibraryModel.shared.blocksGameplayTouch=true;store.activate(entry)
        assert(store.pack?.title==regenerated.title && store.pack?.phone.controls[index].x==movedX)
        assert(store.pack?.actions.contains { $0.label=="Player action fixture" && $0.output=="RB" } == true,"Binding edit lost on regeneration")
        assert(store.pack?.phone.controls.last == moved.phone.controls.last, "Personal overlap/order lost on regeneration")
        store.setAuthoringChoice(entry,key:"mode",value:"keyboardMouse");store.usePreset(entry)
        store.activate(entry)
        assert(store.pack?.inputMode=="controller","Selecting next-launch preset changed the current guest session")
        store.setLaunchPreference(entry,generated:true);store.setAuthoringChoice(entry,key:"mode",value:"auto")
        var incompatible=BCDPackAuthoring.preset(identity:req.identity,title:"Mode change fixture",genre:"strategy",mode:"keyboardMouse")
        incompatible.title="Prepared different input mode"
        try BCDPackStore.encoded(incompatible).write(to:cached,options:.atomic)
        store.activate(entry)
        assert(store.pack?.inputMode=="controller","Cached regeneration changed the running input mode")
        try BCDPackStore.encoded(regenerated).write(to:cached,options:.atomic)
        var unknown=LibraryEntry();unknown.title="Unknown title fixture";unknown.launchRelativePath="unknown-title.exe";unknown.relativePath="unknown-title.exe"
        store.setAuthoringChoice(unknown,key:"genre",value:"racing");store.setAuthoringChoice(unknown,key:"mode",value:"keyboardMouse")
        store.usePreset(unknown)
        store.activate(entry)
        assert(store.pack?.inputMode=="controller","Next-launch preset changed the active session")
        store.activate(unknown)
        assert(store.pack?.inputMode=="keyboardMouse" && store.pack?.identity==store.request(unknown).identity)
        var manual=store.pack!;manual.actions[0].label="Personal accelerator";assert(store.saveEdits(manual))
        store.activate(entry);store.activate(unknown)
        assert(store.pack?.actions[0].label=="Personal accelerator","Manual preset edits lost on reactivation")
        store.activate(entry)
        assert(store.pack?.actions.contains { $0.label=="Player action fixture" } == true,"Preset overwrote researched edits")
        store.setLaunchPreference(entry,generated:false) // Restore the preference expected by the fresh-process phase.
        LibraryModel.shared.blocksGameplayTouch=false
        var invalid=original;invalid.version=999
        try BCDPackStore.encoded(invalid).write(to:cached,options:.atomic)
        let offline=BCDPackStore.Worker(url:"https://127.0.0.1:9",token:"simulator-loopback-fixture-only")
        try BCDPackStore.encoded(offline).write(to:store.folder.appendingPathComponent("worker.json"),options:.atomic)
        entry.id=UUID();store.activate(entry);store.prepare(entry);store.prepare(entry)
        assert(store.pack==nil, "Invalid cache became active")
        for _ in 0..<100 {
            if store.status.hasPrefix("Stock/cached fallback") { break }
            try await Task.sleep(nanoseconds:100_000_000)
        }
        assert(store.status.hasPrefix("Stock/cached fallback"), "Offline worker did not preserve fallback")
        let jobs=try JSONDecoder().decode([String:BCDPackStore.Job].self,from:Data(contentsOf:store.folder.appendingPathComponent("jobs.json")))
        assert(jobs.count==1 && jobs[key]?.attempts==1, "Duplicate preparation created duplicate jobs")
        try BCDPackStore.encoded(regenerated).write(to:cached,options:.atomic)
        try Data("PASS: production Swift store cached/duplicate preparation, invalid cache rejection, real loopback connection failure fallback, and moved override after simulated cache regeneration. Simulator fixture; no real install-completion event or guest.".utf8).write(to:folder.appendingPathComponent("client-phase-1.txt"),options:.atomic)
    }
    @MainActor private func checkWindowRouting(_ p:BCDControlPack) throws {
        let scene=UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        func surfaces(_ v:UIView)->[BCDPackView] {
            (v as? BCDPackView).map { [$0] } ?? v.subviews.flatMap { surfaces($0) }
        }
        let live=scene.windows.flatMap { surfaces($0) }
        assert(live.contains { $0.bounds.width>300 && $0.bounds.height>180 }, "SwiftUI pack surface has no playable frame")
        let library=LibraryModel.shared,store=BCDPackStore.shared
        let previous=library.current,wasEnabled=store.enabled,previousOverride=TouchMouseGate.override
        library.current=NSObject();store.enabled=true;TouchMouseGate.override = .on
        let window=ControlsWindow(windowScene:scene);window.frame=scene.coordinateSpace.bounds
        let root=UIViewController();root.view=UIView(frame:window.bounds)
        let surface=BCDPackView();surface.frame=window.bounds;surface.autoresizingMask=[.flexibleWidth,.flexibleHeight]
        surface.configure(p,context:p.contexts[0],debug:false,editing:false);root.view.addSubview(surface)
        window.rootViewController=root;window.windowLevel = .normal+101;window.isHidden=false;window.layoutIfNeeded()
        defer {
            window.isHidden=true;library.current=previous;store.enabled=wasEnabled
            TouchMouseGate.override=previousOverride;HardwareInput.fixturePointer=false
        }
        for x in [0.2,0.4,0.6,0.8] {
            for y in [0.25,0.5,0.75] {
                let point=CGPoint(x:window.bounds.width*x,y:window.bounds.height*y)
                assert(window.hitTest(point,with:nil) === surface, "Legacy window geometry stole an open-area pack touch")
            }
        }
        assert(TouchMouseGate.suppressing(touchpad:false,desktop:false), "Legacy always-mouse override leaked under a pack")
        let center=CGPoint(x:window.bounds.midX,y:window.bounds.midY)
        HardwareInput.fixturePointer=true
        assert(window.hitTest(center,with:nil)==nil, "Pack swallowed a physical pointer")
        HardwareInput.fixturePointer=false;store.enabled=false
        assert(window.hitTest(center,with:nil)==nil, "Stock hit testing was not restored")
        assert(!TouchMouseGate.suppressing(touchpad:false,desktop:false), "Stock mouse override was not restored")
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        try Data("PASS: production ControlsWindow routes twelve open-area points to pack surface; legacy mouse override suppressed; physical pointer and stock routing preserved. Actual simulator UIKit hit tests with engine/model boundary stubs, no guest.".utf8).write(to:folder.appendingPathComponent("controls-window-routing.txt"),options:.atomic)
    }
    @MainActor private func checkPackInteractions(_ original:BCDControlPack) async throws {
        for _ in 0..<50 {
            if UIApplication.shared.applicationState == .active { break }
            try await Task.sleep(nanoseconds:100_000_000)
        }
        assert(UIApplication.shared.applicationState == .active)
        let scene=UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let library=LibraryModel.shared,store=BCDPackStore.shared,focus=BCDPackFocus.shared,pad=GamepadInput.shared
        let oldCurrent=library.current,oldEnabled=store.enabled,oldTarget=MetalBackedView.keyboardTarget
        let gameWindow=UIWindow(windowScene:scene);gameWindow.frame=scene.coordinateSpace.bounds;gameWindow.windowLevel = .normal+50
        let gameRoot=UIViewController();gameRoot.view=UIView(frame:gameWindow.bounds)
        let gameView=UIView(frame:gameRoot.view.bounds);gameRoot.view.addSubview(gameView)
        gameWindow.rootViewController=gameRoot;gameWindow.isHidden=false;MetalBackedView.keyboardTarget=gameView
        let overlay=ControlsWindow(windowScene:scene);overlay.frame=scene.coordinateSpace.bounds;overlay.windowLevel = .normal+101
        let root=UIViewController();root.view=UIView(frame:overlay.bounds)
        var p=original
        let fireAction=p.actions.first { $0.output=="RT" }!
        let duplicate=BCDControlPack.Control(id:"fixture-left-fire",action:fireAction.id,role:"button",x:0.12,y:0.35,radius:0.04,hitRadius:0.04,opacity:0.5)
        p.phone.controls.append(duplicate)
        let surface=BCDPackView();surface.frame=overlay.bounds;surface.configure(p,context:p.contexts[0],debug:true,editing:false)
        root.view.addSubview(surface);overlay.rootViewController=root;overlay.isHidden=false;overlay.layoutIfNeeded()
        library.current=NSObject();library.blocksGameplayTouch=false;store.enabled=true
        focus.observe(overlay);focus.setMonitoring(true)
        defer {
            surface.clear();overlay.isHidden=true;gameWindow.isHidden=true
            MetalBackedView.keyboardTarget=oldTarget;library.current=oldCurrent;store.enabled=oldEnabled
            focus.setMonitoring(false)
        }
        assert(focus.refresh())
        let safe=surface.bounds.inset(by:surface.safeAreaInsets)
        func point(_ c:BCDControlPack.Control)->CGPoint {CGPoint(x:safe.minX+c.x*safe.width,y:safe.minY+c.y*safe.height)}
        let zone=surface.movementStartRegion
        let start=CGPoint(x:zone.minX+zone.width*0.08,y:zone.minY+zone.height*0.45)
        let move=p.phone.controls.first { $0.role=="move" }!
        assert(hypot(start.x-point(move).x,start.y-point(move).y)>move.hitRadius*min(safe.width,safe.height),"Fixture must start outside the old fixed pad")
        var t=ProcessInfo.processInfo.systemUptime
        surface.beginTouch("move",at:start,time:t)
        assert(surface.activeTouchRoles==["move"] && surface.movementVisual!.origin==start,"Floating movement did not acquire at thumb landing")
        t+=0.02;surface.moveTouch("move",to:CGPoint(x:start.x+45,y:start.y),time:t)
        assert(pad.sample.lx>0)
        surface.beginTouch("left-fire",at:point(duplicate),time:t)
        let aim=p.phone.aimRect
        let look=CGPoint(x:safe.minX+(aim.x+aim.width/2)*safe.width,y:safe.minY+(aim.y+aim.height/2)*safe.height)
        surface.beginTouch("look",at:look,time:t)
        let primary=p.phone.controls.first { $0.role=="fireAim" }!
        surface.beginTouch("primary-fire",at:point(primary),time:t)
        assert(pad.sample.lx>0 && pad.sample.rt==255,"Another finger cleared movement/fire")
        let lookOwner=pad.lookOwner
        surface.endTouch("primary-fire",at:point(primary),cancelled:false)
        assert(pad.sample.rt==255 && pad.sample.lx>0 && pad.lookOwner==lookOwner,"Primary release cancelled an independent owner")
        t+=0.02;surface.moveTouch("look",to:point(primary),time:t)
        assert(surface.activeTouchRoles.contains("look") && pad.lookMoves>0,"Swipe crossing a button lost ownership")
        if let radial=p.phone.controls.first(where:{$0.role=="radial"}) {
            surface.beginTouch("radial",at:point(radial),time:t)
            assert(!surface.radialLabelFrames.isEmpty)
            assert(surface.radialLabelFrames.allSatisfy { safe.insetBy(dx:-1,dy:-1).contains($0) },"Peripheral radial labels clipped off-screen")
            surface.endTouch("radial",at:point(radial),cancelled:true)
        }
        assert(PackBoundarySpy.keyboardEvents==0 && PackBoundarySpy.mouseEvents==0,"Controller surface emitted keyboard/mouse events")
        surface.clear()
        var overlapping = p; overlapping.version = 2
        let rtIndex = overlapping.phone.controls.firstIndex { $0.action == "rt" }!
        let aIndex = overlapping.phone.controls.firstIndex { $0.action == "a" }!
        overlapping.actions[overlapping.actions.firstIndex { $0.id == "a" }!].behavior = "hold"
        for i in [rtIndex, aIndex] {
            overlapping.phone.controls[i].coordinateSpace = "screen"
            overlapping.phone.controls[i].x = 0.55; overlapping.phone.controls[i].y = 0.5
            overlapping.phone.controls[i].role = "button"
        }
        let top = overlapping.phone.controls.remove(at: aIndex); overlapping.phone.controls.append(top)
        try overlapping.validate(placement: .personal)
        surface.configure(overlapping, context:p.contexts[0], debug:true, editing:false)
        let overlapPoint = surface.controlCenter(top)
        surface.beginTouch("independent-fire", at:point(duplicate), time:t+0.03)
        surface.beginTouch("top-overlap", at:overlapPoint, time:t+0.03)
        assert(pad.sample.buttons & TouchPadAction.buttons["A"]! != 0 && pad.sample.rt == 255, "Topmost overlapping button did not acquire independently")
        surface.endTouch("top-overlap", at:overlapPoint, cancelled:true)
        assert(pad.sample.buttons == 0 && pad.sample.rt == 255, "Cancelling an overlap released another finger")
        let empty = CGPoint(x:surface.bounds.width*0.5,y:surface.bounds.height*0.3)
        surface.beginTouch("cross-overlap",at:empty,time:t+0.04)
        let crossingOwner=pad.lookOwner
        surface.moveTouch("cross-overlap",to:overlapPoint,time:t+0.06)
        assert(pad.lookOwner==crossingOwner && pad.sample.buttons == 0 && surface.activeTouchRoles.contains("look"), "Overlap stole an existing look finger")
        surface.clear()
        let beforeDrag=store.pack!
        surface.configure(beforeDrag,context:p.contexts[0],debug:true,editing:true)
        let dragged=beforeDrag.phone.controls.first { $0.role == "fireAim" }!
        let from=surface.controlCenter(dragged),destination=CGPoint(x:5,y:surface.bounds.maxY-5)
        surface.beginTouch("personal-drag",at:from,time:t+0.07)
        surface.moveTouch("personal-drag",to:destination,time:t+0.08)
        surface.endTouch("personal-drag",at:destination,cancelled:false)
        let placed=store.pack!.phone.controls.first { $0.id == dragged.id }!
        assert(placed.coordinateSpace == "screen" && abs(surface.controlCenter(placed).x-5)<0.001 && abs(surface.controlCenter(placed).y-destination.y)<0.001, "Drag did not save at full display coordinates")
        let edge=surface.positionedControl(dragged,at:CGPoint(x:-10,y:surface.bounds.maxY+10))
        assert(edge.x == 0 && edge.y == 1, "Placement must reach the display edge and stop outside it")
        store.undoEdit();assert(store.pack == beforeDrag)
        try Data("PASS: production personal drag saves at display edge; overlap uses last-drawn control, cancellation preserves another held trigger, crossing look keeps ownership; regeneration/restart checked separately. Simulator with engine spies, no guest.".utf8).write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("free-placement-regression.txt"))
        surface.clear()
        var keyboard=BCDPackAuthoring.preset(identity:p.identity,title:"Keyboard fixture",genre:"first-person",mode:"keyboardMouse")
        let one=keyboard.actions.firstIndex { $0.output=="key:87" }!,two=keyboard.actions.firstIndex { $0.output=="key:83" }!
        keyboard.actions[one].output="keys:17+87";keyboard.actions[two].output="keys:17+83"
        surface.configure(keyboard,context:"onFoot",debug:false,editing:false)
        func keyPoint(_ id:String)->CGPoint {
            let c=keyboard.phone.controls.first { $0.action==id }!
            return CGPoint(x:safe.minX+c.x*safe.width,y:safe.minY+c.y*safe.height)
        }
        PackBoundarySpy.keys=[];PackBoundarySpy.mouse=[]
        surface.beginTouch("chord-one",at:keyPoint(keyboard.actions[one].id),time:t+0.1)
        surface.beginTouch("chord-two",at:keyPoint(keyboard.actions[two].id),time:t+0.1)
        assert(PackBoundarySpy.keys.filter { $0.0==17 && $0.1==1 }.count==1,"Shared modifier pressed twice")
        surface.endTouch("chord-one",at:keyPoint(keyboard.actions[one].id),cancelled:false)
        assert(!PackBoundarySpy.keys.contains { $0.0==17 && $0.1==0 },"First chord released another owner's modifier")
        surface.endTouch("chord-two",at:keyPoint(keyboard.actions[two].id),cancelled:true)
        assert(PackBoundarySpy.keys.filter { $0.0==17 && $0.1==0 }.count==1,"Cancellation left modifier held")
        let click=keyboard.actions.firstIndex { $0.output=="mouse:left" }!
        keyboard.actions[click].output="mouse:middle"
        surface.configure(keyboard,context:"onFoot",debug:false,editing:false)
        surface.beginTouch("middle",at:keyPoint(keyboard.actions[click].id),time:t+0.2)
        surface.endTouch("middle",at:keyPoint(keyboard.actions[click].id),cancelled:true)
        assert(PackBoundarySpy.mouse.contains { $0.0==32 } && PackBoundarySpy.mouse.contains { $0.0==64 },"Middle click not balanced")
        keyboard.actions[click].output="mouse:wheelDown";keyboard.actions[click].behavior="tap"
        for device in [false,true] {
            var layout=device ? keyboard.pad : keyboard.phone
            for i in layout.controls.indices where layout.controls[i].action==keyboard.actions[click].id {layout.controls[i].role="button"}
            if device {keyboard.pad=layout}else{keyboard.phone=layout}
        }
        surface.configure(keyboard,context:"onFoot",debug:false,editing:false)
        surface.beginTouch("wheel",at:keyPoint(keyboard.actions[click].id),time:t+0.3)
        surface.endTouch("wheel",at:keyPoint(keyboard.actions[click].id),cancelled:false)
        assert(PackBoundarySpy.mouse.filter { $0.0==0x800 && Int32(bitPattern:$0.1)==(-120) }.count==1,"Wheel tap repeated or used wrong sign")
        surface.clear();surface.configure(p,context:p.contexts[0],debug:true,editing:false)
        surface.beginTouch("held-for-dialog",at:point(duplicate),time:t+0.4)

        // The exact failure on the phone: main-window alert below the full-screen controls window.
        let alert=UIAlertController(title:"Fixture notification",message:"Must own its buttons",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"OK",style:.default))
        gameRoot.present(alert,animated:false)
        try await Task.sleep(nanoseconds:150_000_000)
        assert(!focus.refresh() && focus.blockedByPresentation)
        assert(surface.activeTouchRoles.isEmpty && pad.sample==GamepadSample(),"Dialog did not clear held inputs")
        let alertPoint=alert.view.convert(CGPoint(x:alert.view.bounds.midX,y:alert.view.bounds.midY),to:overlay)
        assert(overlay.hitTest(alertPoint,with:nil)==nil,"Pack stole the main-window alert touch")
        alert.dismiss(animated:false)
        try await Task.sleep(nanoseconds:150_000_000)
        assert(focus.refresh() && !focus.blockedByPresentation)
        surface.beginTouch("after-dialog",at:point(duplicate),time:t+1)
        assert(pad.sample.rt==255,"First touch after dialog dismissal was lost to stale focus")
        surface.endTouch("after-dialog",at:point(duplicate),cancelled:true)
        // A native presentation belonging to the controls window must remain interactive.
        let own=UIAlertController(title:"Pack settings fixture",message:nil,preferredStyle:.alert)
        own.addAction(UIAlertAction(title:"Back to game",style:.cancel))
        root.present(own,animated:false)
        try await Task.sleep(nanoseconds:150_000_000)
        assert(!focus.refresh() && !focus.blockedByPresentation)
        let ownPoint=own.view.convert(CGPoint(x:own.view.bounds.midX,y:own.view.bounds.midY),to:overlay)
        assert(overlay.hitTest(ownPoint,with:nil)?.isDescendant(of:own.view)==true,"Pack settings lost their native dismissal surface")
        own.dismiss(animated:false)
        try await Task.sleep(nanoseconds:150_000_000)
        assert(focus.refresh())
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        try Data("PASS: actual BCDPackView event adapters acquire floating movement outside the old circle; base follows thumb landing; simultaneous movement/independent RT/look ownership; crossing controls stays look; zero keyboard/mouse emissions; actual main-window UIAlert owns touches and clears held input; first touch after dismissal works; native pack dialog keeps dismissal routing. Simulator UIKit with engine boundary spies, not a guest game.".utf8).write(to:folder.appendingPathComponent("pack-interaction-regression.txt"),options:.atomic)
    }
    @MainActor private func captureAuthoringFixtures() throws {
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let identity=BCDControlPack.Identity(executable:"unknown-fixture.exe",storeID:"local",edition:"fixture",build:"unreported",bindingDigest:"fixture")
        for (genre,_) in BCDPackCatalog.genres {
            for mode in ["controller","keyboardMouse"] {
                let original=BCDPackAuthoring.preset(identity:identity,title:"Unidentified game fixture",genre:genre,mode:mode)
                for isPad in [false,true] {
                    let size=isPad ? CGSize(width:1194,height:834) : CGSize(width:956,height:440)
                    let insets=isPad ? UIEdgeInsets(top:24,left:0,bottom:20,right:0) : UIEdgeInsets(top:0,left:62,bottom:21,right:62)
                    var p=original;if isPad {p.phone=p.pad}
                    let view=BCDPackView();view.frame=CGRect(x:0,y:0,width:size.width-insets.left-insets.right,height:size.height-insets.top-insets.bottom)
                    view.configure(p,context:"onFoot",debug:true,editing:false)
                    let format=UIGraphicsImageRendererFormat();format.scale=2;format.opaque=true
                    let image=UIGraphicsImageRenderer(size:size,format:format).image { context in
                        UIColor.black.setFill();context.fill(CGRect(origin:.zero,size:size))
                        context.cgContext.saveGState();context.cgContext.translateBy(x:insets.left,y:insets.top)
                        view.draw(view.bounds);context.cgContext.restoreGState()
                        let label="PRESET GEOMETRY FIXTURE / NO GAME / \(genre) / \(mode) / \(isPad ? "iPad geometry" : "phone geometry")"
                        (label as NSString).draw(at:CGPoint(x:30,y:5),withAttributes:[.font:UIFont.systemFont(ofSize:10),.foregroundColor:UIColor.white])
                    }
                    try image.pngData()!.write(to:folder.appendingPathComponent("template-"+genre+"-"+mode+"-"+(isPad ? "pad" : "phone")+".png"))
                }
            }
        }
        let size=CGSize(width:956,height:700),format=UIGraphicsImageRendererFormat();format.scale=2;format.opaque=true
        let catalog=UIGraphicsImageRenderer(size:size,format:format).image { context in
            UIColor.black.setFill();context.fill(CGRect(origin:.zero,size:size))
            ("LOCAL SF SYMBOL CATALOG FIXTURE / NOT CUSTOM ARTWORK / NO GAME" as NSString).draw(at:CGPoint(x:20,y:10),withAttributes:[.font:UIFont.boldSystemFont(ofSize:14),.foregroundColor:UIColor.white])
            for (i,icon) in BCDPackCatalog.icons.enumerated() {
                let x=CGFloat(i%6)*155+28,y=CGFloat(i/6)*82+52
                UIImage(systemName:icon.id)!.withTintColor(.white,renderingMode:.alwaysOriginal).draw(in:CGRect(x:x+45,y:y,width:28,height:28))
                (icon.label as NSString).draw(in:CGRect(x:x,y:y+35,width:150,height:40),withAttributes:[.font:UIFont.systemFont(ofSize:12),.foregroundColor:UIColor.white])
            }
        }
        try catalog.pngData()!.write(to:folder.appendingPathComponent("authoring-icon-catalog-fixture.png"))
        try Data("PASS: five genre presets in each input mode, phone and iPad geometry exported by production renderer; catalog symbols available. Simulator fixture, no actual iPad or game.".utf8).write(to:folder.appendingPathComponent("authoring-fixtures.txt"))
    }
    @MainActor private func captureEditorFixtures() async throws {
        let scene=UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        assert(BCDPackCatalog.icons.allSatisfy { UIImage(systemName:$0.id) != nil }, "Icon catalog contains an unavailable symbol")
        func canvas(in view:UIView) -> BCDPackView? {
            if let surface=view as? BCDPackView { return surface }
            for child in view.subviews { if let surface=canvas(in:child) { return surface } }
            return nil
        }
        for height in [320,440] {
            let size=CGSize(width:956,height:CGFloat(height))
            let window=UIWindow(windowScene:scene);window.frame=CGRect(origin:.zero,size:size);window.windowLevel = .normal+102
            let host=UIHostingController(rootView:ZStack(alignment:.topLeading) {
                Color.black
                BCDPackInspector().frame(width:380,height:CGFloat(height)-24).padding(12)
            })
            window.rootViewController=host;window.isHidden=false;host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds:150_000_000)
            let format=UIGraphicsImageRendererFormat();format.scale=2;format.opaque=true
            let image=UIGraphicsImageRenderer(size:size,format:format).image { _ in host.view.drawHierarchy(in:CGRect(origin:.zero,size:size),afterScreenUpdates:true) }
            try image.pngData()!.write(to:folder.appendingPathComponent("editor-\(height)-simulator.png"))
            window.isHidden=true
            let store=BCDPackStore.shared,wasEditing=BCDPackStore.shared.editing,wasPlacing=BCDPackStore.shared.placingControls
            store.editing=true;store.placingControls=true
            let compact=UIHostingController(rootView:ZStack { Color.black; BCDPackLayer() }.ignoresSafeArea())
            window.rootViewController=compact;window.isHidden=false;compact.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds:150_000_000)
            let placementCanvas=canvas(in:compact.view)!
            for x in [0.15,0.35,0.65,0.85] {
                for y in [0.5,0.8] {
                    let point=CGPoint(x:compact.view.bounds.width*x,y:compact.view.bounds.height*y)
                    assert(compact.view.hitTest(point,with:nil) === placementCanvas, "Compact placement toolbar blocks the canvas")
                }
            }
            let compactImage=UIGraphicsImageRenderer(size:size,format:format).image { _ in compact.view.drawHierarchy(in:CGRect(origin:.zero,size:size),afterScreenUpdates:true) }
            try compactImage.pngData()!.write(to:folder.appendingPathComponent("placement-\(height)-simulator.png"))
            window.isHidden=true;store.editing=wasEditing;store.placingControls=wasPlacing
        }
    }
}
