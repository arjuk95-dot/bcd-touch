// Actual production UIKit touch adapter; engine boundary spies, not guest validation.
import UIKit
import SwiftUI

@MainActor enum BCDSulfurTouchFixtures {
    static func run() async throws {
        for _ in 0..<50 {
            if UIApplication.shared.applicationState == .active { break }
            try await Task.sleep(nanoseconds:100_000_000)
        }
        assert(UIApplication.shared.applicationState == .active)
        let scene=UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first!
        let library=LibraryModel.shared,store=BCDPackStore.shared,focus=BCDPackFocus.shared,pad=GamepadInput.shared
        let oldCurrent=library.current,oldEnabled=store.enabled,oldTarget=MetalBackedView.keyboardTarget
        let oldBlocked=library.blocksGameplayTouch,oldEntry=library.activeEntry
        let gameWindow=UIWindow(windowScene:scene);gameWindow.frame=scene.coordinateSpace.bounds;gameWindow.windowLevel = .normal+50
        let gameRoot=UIViewController();gameRoot.view=UIView(frame:gameWindow.bounds);gameRoot.view.backgroundColor = .black
        let gameView=MetalBackedView(frame:gameRoot.view.bounds);gameRoot.view.addSubview(gameView)
        gameWindow.rootViewController=gameRoot;gameWindow.isHidden=false;MetalBackedView.keyboardTarget=gameView
        let overlay=ControlsWindow(windowScene:scene);overlay.frame=scene.coordinateSpace.bounds;overlay.windowLevel = .normal+101
        let root=UIViewController();root.view=UIView(frame:overlay.bounds)
        let surface=BCDPackView();surface.frame=overlay.bounds;root.view.addSubview(surface)
        overlay.rootViewController=root;overlay.isHidden=false;overlay.layoutIfNeeded()
        library.current=NSObject();library.blocksGameplayTouch=false;store.enabled=true
        focus.observe(overlay);focus.setMonitoring(true)
        defer {
            surface.clear();overlay.isHidden=true;gameWindow.isHidden=true
            MetalBackedView.keyboardTarget=oldTarget;library.current=oldCurrent;store.enabled=oldEnabled
            library.blocksGameplayTouch=oldBlocked;library.activeEntry=oldEntry;focus.setMonitoring(false)
        }
        assert(focus.refresh())
        let id=BCDControlPack.Identity(executable:"Games/SULFUR/Sulfur.exe",storeID:"local",edition:"installed",build:"fixture",bindingDigest:"fixture")
        let original=try BCDSulfurPack.make(identity:id)
        let x=TouchPadAction.buttons["X"]!,b=TouchPadAction.buttons["B"]!
        // Both fresh defaults and a retained older personalized plain-button role.
        for legacy in [false,true] {
            var p=original
            if legacy {
                for i in p.phone.controls.indices where ["attack","melee"].contains(p.phone.controls[i].action) {
                    p.phone.controls[i].role="button"
                    p.phone.controls[i].opacity=0.55 // personal edit remains untouched
                }
            }
            surface.configure(p,context:"onFoot",debug:false,editing:false)
            func point(_ action:String)->CGPoint {surface.controlCenter(p.phone.controls.first{$0.action==action}!)}
            let attack=point("attack"),melee=point("melee"),jump=point("jump")
            let safe=surface.bounds.inset(by:surface.safeAreaInsets),a=p.phone.aimRect
            let look=CGPoint(x:safe.minX+(a.x+a.width/2)*safe.width,y:safe.minY+(a.y+a.height/2)*safe.height)
            let zone=surface.movementStartRegion,move=CGPoint(x:zone.midX,y:zone.midY)
            var t=ProcessInfo.processInfo.systemUptime
            let keys=PackBoundarySpy.keyboardEvents,mouse=PackBoundarySpy.mouseEvents
            surface.beginTouch("move",at:move,time:t)
            surface.moveTouch("move",to:CGPoint(x:move.x+30,y:move.y),time:t+0.01)
            surface.beginTouch("attack",at:attack,time:t)
            surface.beginTouch("melee",at:melee,time:t)
            assert(pad.sample.rt==255 && pad.sample.buttons & x != 0 && pad.sample.lx>0)
            for (name,position) in [("attack",attack),("melee",melee)] {
                let before=PackBoundarySpy.relativeMoves;t+=0.03
                surface.moveTouch(name,to:CGPoint(x:position.x+24,y:position.y+8),time:t)
                assert(PackBoundarySpy.relativeMoves>before,"Held combat thumb failed to swipe-look: \(name), legacy=\(legacy)")
                assert(pad.sample.rt==255 && pad.sample.buttons & x != 0 && pad.sample.lx>0,"Combat drag dropped another owner")
                assert(pad.lookOwner==nil,"Hybrid mouse drag acquired an RS owner")
            }
            surface.beginTouch("look",at:look,time:t)
            let before=PackBoundarySpy.relativeMoves;t+=0.03
            surface.moveTouch("look",to:CGPoint(x:look.x+30,y:look.y-10),time:t)
            assert(PackBoundarySpy.relativeMoves>before && pad.sample.rt==255 && pad.sample.buttons & x != 0,"Independent swipe lost while RT/X held")
            surface.beginTouch("jump",at:jump,time:t)
            assert(pad.sample.buttons & b != 0 && pad.sample.rt==255 && pad.sample.buttons & x != 0,"Direct Jump dropped combat")
            surface.endTouch("jump",at:jump,cancelled:true)
            assert(pad.sample.buttons & b == 0 && pad.sample.buttons & x != 0 && pad.sample.rt==255)
            surface.endTouch("attack",at:attack,cancelled:true)
            assert(pad.sample.rt==0 && pad.sample.buttons & x != 0 && pad.sample.lx>0)
            surface.endTouch("melee",at:melee,cancelled:false)
            assert(pad.sample.buttons & x == 0 && pad.sample.lx>0)
            let afterRelease=PackBoundarySpy.relativeMoves;t+=0.03
            surface.moveTouch("look",to:CGPoint(x:look.x+45,y:look.y),time:t)
            assert(PackBoundarySpy.relativeMoves>afterRelease,"Combat release stole independent look")
            assert(PackBoundarySpy.keyboardEvents==keys && PackBoundarySpy.mouseEvents==mouse,"Hybrid combat emitted a keyboard or mouse button")
            surface.clear();assert(pad.sample==GamepadSample())
            surface.beginTouch("held-menu",at:attack,time:t+0.1)
            library.blocksGameplayTouch=true
            surface.moveTouch("held-menu",to:look,time:t+0.2)
            assert(surface.activeTouchRoles.isEmpty && pad.sample==GamepadSample(),"Menu left combat held")
            library.blocksGameplayTouch=false
            surface.beginTouch("held-focus",at:melee,time:t+0.3)
            NotificationCenter.default.post(name:BCDPackFocus.didLoseFocus,object:nil)
            assert(surface.activeTouchRoles.isEmpty && pad.sample==GamepadSample(),"Focus loss left melee held")
            surface.configure(p,context:"inventory",debug:false,editing:false)
            let inventoryBefore=PackBoundarySpy.relativeMoves
            surface.beginTouch("inventory-look",at:look,time:t+0.4)
            surface.moveTouch("inventory-look",to:CGPoint(x:look.x+25,y:look.y),time:t+0.5)
            assert(PackBoundarySpy.relativeMoves==inventoryBefore,"Inventory emitted camera motion")
            surface.clear()
        }
        // Production editor handlers and store persistence: no game input while editing.
        var entry=LibraryEntry();entry.title="Editor fixture";entry.relativePath="fixture-editor/Sulfur.exe";entry.launchRelativePath=entry.relativePath
        store.selectReviewedProfile(entry,selected:true);store.activate(nil);store.applyLaunchPreference(entry);store.activate(entry)
        let originalEditing=store.editing,originalPlacing=store.placingControls,originalTuning=store.tuningControls
        defer {store.editing=originalEditing;store.placingControls=originalPlacing;store.tuningControls=originalTuning;store.activate(nil)}
        store.editing=true;store.placingControls=true
        let baseline=store.pack!,attackControl=baseline.phone.controls.first{$0.action == "attack"}!
        surface.configure(baseline,context:"onFoot",debug:false,editing:true)
        let attack=surface.controlCenter(attackControl),t=ProcessInfo.processInfo.systemUptime
        let keys=PackBoundarySpy.keyboardEvents,mouse=PackBoundarySpy.mouseEvents,relative=PackBoundarySpy.relativeMoves
        surface.beginTouch("editor-tap",at:attack,time:t)
        surface.endTouch("editor-tap",at:attack,cancelled:false,time:t+0.1)
        assert(store.selectedControl==attackControl.id && store.pack==baseline,"Tap must select without rewriting layout")
        surface.beginTouch("editor-drag",at:attack,time:t+0.2)
        let destination=CGPoint(x:attack.x-35,y:attack.y-15)
        surface.moveTouch("editor-drag",to:destination,time:t+0.3)
        surface.endTouch("editor-drag",at:destination,cancelled:false,time:t+0.4)
        assert(store.pack!.phone.controls.first{$0.id == attackControl.id}?.coordinateSpace=="screen")
        assert(store.pack!.pad==baseline.pad && store.pack!.actions==baseline.actions)
        store.undoEdit();assert(store.pack==baseline)
        surface.configure(baseline,context:"onFoot",debug:false,editing:true)
        assert(surface.beginControlResize(at:attack));surface.updateControlResize(scale:1.3)
        assert(store.pack==baseline,"Pinch preview prematurely changed persistent layout")
        surface.endControlResize(cancelled:false)
        let sized=store.pack!,updated=sized.phone.controls.first{$0.id==attackControl.id}!
        assert(abs(updated.radius-attackControl.radius*1.3)<0.000001 && sized.pad==baseline.pad && sized.actions==baseline.actions)
        store.undoEdit();assert(store.pack==baseline,"One Undo must undo the whole pinch")
        surface.configure(baseline,context:"onFoot",debug:false,editing:true)
        assert(surface.beginControlResize(at:attack));surface.updateControlResize(scale:1.5);surface.endControlResize(cancelled:true)
        assert(store.pack==baseline)
        assert(surface.beginControlResize(at:attack));surface.updateControlResize(scale:.nan);surface.endControlResize(cancelled:false)
        assert(store.pack==baseline,"Invalid pinch scale changed layout")
        assert(surface.beginControlResize(at:attack));surface.updateControlResize(scale:1.5)
        NotificationCenter.default.post(name:BCDPackFocus.didLoseFocus,object:nil);surface.endControlResize(cancelled:false)
        assert(store.pack==baseline,"Interrupted pinch changed layout")
        assert(surface.beginControlResize(at:attack));surface.updateControlResize(scale:1.5)
        NotificationCenter.default.post(name:UIDevice.orientationDidChangeNotification,object:nil);surface.endControlResize(cancelled:false)
        assert(store.pack==baseline,"Rotation committed a stale pinch")
        surface.configure(baseline,context:"onFoot",debug:false,editing:true)
        assert(surface.beginControlResize(at:attack));surface.updateControlResize(scale:1.5)
        surface.configure(baseline,context:"onFoot",debug:false,editing:false);surface.endControlResize(cancelled:false)
        assert(store.pack==baseline && !surface.beginControlResize(at:attack),"Gameplay allowed button resize")
        store.selectedControl=attackControl.id;store.resizeSelectedControl(scale:1.1,pad:false)
        let buttonEdited=store.pack!;store.setSwipeSensitivity(2.75)
        var expected=buttonEdited;expected.aim.sensitivity=2.75
        assert(store.pack==expected,"Swipe tuning changed other personal choices")
        store.setSwipeSensitivity(.nan);assert(store.pack==expected)
        let reloaded=BCDPackStore(folder:store.folder);reloaded.applyLaunchPreference(entry);reloaded.activate(entry)
        // The established three-way merge appends player-edit provenance on reload.
        // Compare every other field exactly, including both layouts, bindings and aim.
        var expectedReloaded=expected;BCDPackAuthoring.ensurePlayerEvidence(&expectedReloaded)
        if reloaded.pack != expectedReloaded {
            let diagnostics=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            try BCDPackStore.encoded(expectedReloaded).write(to:diagnostics.appendingPathComponent("editor-reload-expected.json"))
            try BCDPackStore.encoded(reloaded.pack).write(to:diagnostics.appendingPathComponent("editor-reload-actual.json"))
        }
        assert(reloaded.pack==expectedReloaded,"Size and swipe choices did not persist (apart from required player-edit provenance)")
        assert(PackBoundarySpy.keyboardEvents==keys && PackBoundarySpy.mouseEvents==mouse && PackBoundarySpy.relativeMoves==relative && pad.sample==GamepadSample(),"Editor leaked gameplay input")
        let editorFolder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        try Data("PASS: production tap selection, drag movement, pinch preview/commit/cancel/invalid/focus/exit, one-step Undo, +/- sizing, preserved bindings and other layout, swipe tuning and restart persistence; UIKit engine boundary spies, no physical pinch or guest test.".utf8).write(to:editorFolder.appendingPathComponent("editor-tuning-regression.txt"))
        try await checkAllTitleEditing(surface:surface)
        store.activate(nil);store.applyLaunchPreference(entry);store.activate(entry)
        // Five bounded production SwiftUI previews for visual QA, not the broad HUD sweep.
        library.activeEntry=entry;store.editing=true;store.placingControls=true;store.tuningControls=false
        let editorHost=UIHostingController(rootView:BCDPackLayer());editorHost.overrideUserInterfaceStyle = .dark;editorHost.view.frame=overlay.bounds
        overlay.rootViewController=editorHost
        func snapshot(_ name:String) async throws {
            try await Task.sleep(nanoseconds:250_000_000)
            editorHost.view.layoutIfNeeded()
            let image=UIGraphicsImageRenderer(bounds:editorHost.view.bounds).image{_ in editorHost.view.drawHierarchy(in:editorHost.view.bounds,afterScreenUpdates:true)}
            try image.pngData()!.write(to:editorFolder.appendingPathComponent(name))
        }
        try await snapshot("editor-placement.png")
        store.placingControls=false;store.tuningControls=true
        try await snapshot("editor-aim-gyro.png")
        for (exe,name) in [("Inscryption.exe","editor-inscryption-arrows.png"),("SlayTheSpire2.exe","editor-spire-controls.png")] {
            var preview=LibraryEntry();preview.title=exe;preview.relativePath="fixture-visual/"+exe;preview.launchRelativePath=preview.relativePath
            library.activeEntry=preview;store.activate(nil);store.setLaunchPreference(preview,generated:true);store.applyLaunchPreference(preview);store.activate(preview)
            store.editing=false;store.placingControls=false;store.tuningControls=false
            try await snapshot(name)
        }
        let fallbackHost=UIHostingController(rootView:BCDControllerFallback(accepting:true,output:{_,_ in},close:{}))
        fallbackHost.overrideUserInterfaceStyle = .dark;fallbackHost.view.frame=CGRect(x:overlay.bounds.width-440,y:40,width:420,height:300)
        overlay.rootViewController=fallbackHost
        try await Task.sleep(nanoseconds:250_000_000);fallbackHost.view.layoutIfNeeded()
        let fallbackImage=UIGraphicsImageRenderer(bounds:fallbackHost.view.bounds).image{_ in fallbackHost.view.drawHierarchy(in:fallbackHost.view.bounds,afterScreenUpdates:true)}
        try fallbackImage.pngData()!.write(to:editorFolder.appendingPathComponent("editor-controller-fallback.png"))
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        try Data("PASS: production SULFUR fresh and legacy-personal combat roles; simultaneous LS + RT + X + independent mouse look; drag on each held combat button; direct Jump; independent cancellation/release; menu/focus release; inventory has no camera. UIKit with engine spies only, no guest or sensor validation.".utf8).write(to:folder.appendingPathComponent("sulfur-combat-regression.txt"))
    }
}
