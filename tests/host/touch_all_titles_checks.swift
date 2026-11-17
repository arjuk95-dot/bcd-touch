import UIKit

/// Same production editor and store for every installed title. Only simulator fixtures.
@MainActor func checkAllTitleEditing(surface:BCDPackView) async throws {
    let store=BCDPackStore.shared,pad=GamepadInput.shared
    let oldController=GamepadInput.packControllerSession,oldMouse=GamepadInput.packKeyboardMouseSession
    defer {store.setControllerFallback(false);GamepadInput.packControllerSession=oldController;GamepadInput.packKeyboardMouseSession=oldMouse}
    let config=LibraryEntry.hostDrive.appendingPathComponent(BCDChroniclesPack.configPath)
    let previous=try? Data(contentsOf:config)
    try FileManager.default.createDirectory(at:config.deletingLastPathComponent(),withIntermediateDirectories:true)
    try Data("[varcom]\nM=32\nN=0\nO=5\nP=1\nQ=2\nR=3\nT=6\nU=7\n".utf8).write(to:config)
    defer {if let previous {try? previous.write(to:config)} else {try? FileManager.default.removeItem(at:config)}}
    let cases=[("QueensDomain.exe","Queen"),("Sulfur.exe","SULFUR"),("Dread Delusion.exe","Dread"),("Cotw.exe","Chronicles of the Wolf"),("TenebrisSomnia.exe","Tenebris"),("SKALD Against the Black Priory.exe","SKALD"),("SlayTheSpire2.exe","Spire"),("Inscryption.exe","Inscryption"),("Noita.exe","Noita")]
    for (exe,title) in cases {
        var entry=LibraryEntry();entry.title=title;entry.relativePath="fixture-all-title/"+exe;entry.launchRelativePath=entry.relativePath
        store.activate(nil);store.setLaunchPreference(entry,generated:true);store.applyLaunchPreference(entry);store.activate(entry)
        guard let base=store.pack else {preconditionFailure("Missing editable profile: "+title)}
        store.beginEditingControls();surface.configure(base,context:base.contexts[0],debug:false,editing:true)
        let control=base.phone.controls.last{c in c.role == "button" && base.actions.contains{a in a.id == c.action && a.contexts.contains(base.contexts[0])}}!
        let start=surface.controlCenter(control),end=CGPoint(x:start.x+14,y:start.y+9),time=ProcessInfo.processInfo.systemUptime
        let keys=PackBoundarySpy.keyboardEvents,mouse=PackBoundarySpy.mouseEvents,relative=PackBoundarySpy.relativeMoves
        surface.beginTouch("all-title-drag",at:start,time:time)
        surface.moveTouch("all-title-drag",to:end,time:time+0.1)
        surface.endTouch("all-title-drag",at:end,cancelled:false,time:time+0.2)
        guard let moved=store.pack,let selected=moved.phone.controls.first(where:{$0.id == store.selectedControl}) else {preconditionFailure("No selected control: "+title)}
        assert(selected.coordinateSpace == "screen" && moved != base,"Drag did not move control: "+title)
        surface.configure(moved,context:moved.contexts[0],debug:false,editing:true)
        assert(surface.beginControlResize(at:surface.controlCenter(selected)),"Pinch not available: "+title)
        surface.updateControlResize(scale:0.9);surface.endControlResize(cancelled:false)
        let edited=store.pack!
        assert(edited.phone.controls.first{$0.id == selected.id}!.radius < selected.radius,"Pinch did not resize: "+title)
        assert(edited.pad == base.pad && edited.actions == base.actions && edited.identity == base.identity,"Editor modified unrelated data: "+title)
        var expected=edited;BCDPackAuthoring.ensurePlayerEvidence(&expected)
        let restored=BCDPackStore(folder:store.folder);restored.applyLaunchPreference(entry);restored.activate(entry)
        assert(restored.pack == expected,"Move/resize did not persist: "+title)
        assert(PackBoundarySpy.keyboardEvents == keys && PackBoundarySpy.mouseEvents == mouse && PackBoundarySpy.relativeMoves == relative && pad.sample == GamepadSample(),"Editor emitted game input: "+title)
        // Dedicated iPad geometry stays independently resizable even on this phone fixture.
        store.selectedControl=edited.pad.controls[0].id;store.resizeSelectedControl(scale:0.9,pad:true)
        assert(store.pack!.phone == edited.phone && store.pack!.pad != edited.pad)
        surface.clear()
        if title == "Spire" {
            assert(store.usesController && !store.usesCursor && store.tableSurface.isEmpty,"Spire must retain native controller enumeration")
            assert(!edited.actions.contains{$0.id.lowercased().contains("inspect")})
            let retained=store.pack!,url=store.folder.appendingPathComponent("personal-edits-v2.json"),bytes=try Data(contentsOf:url)
            store.editing=false;surface.configure(retained,context:"onFoot",debug:false,editing:false)
            let cancel=surface.controlCenter(retained.phone.controls.first{$0.action == "cancel"}!)
            let map=surface.controlCenter(retained.phone.controls.first{$0.action == "map"}!)
            var now=ProcessInfo.processInfo.systemUptime
            store.spireUtilitiesVerified=false
            surface.beginTouch("unverified-cancel",at:cancel,time:now)
            assert(pad.sample == GamepadSample(),"Unverified Spire mapping emitted input")
            surface.endTouch("unverified-cancel",at:cancel,cancelled:false,time:now+0.01)
            surface.beginTouch("unverified-map",at:map,time:now+0.02)
            assert(pad.sample == GamepadSample(),"Unverified Map emitted input")
            surface.endTouch("unverified-map",at:map,cancelled:false,time:now+0.03)
            surface.clear();surface.configure(retained,context:"onFoot",debug:false,editing:false)
            store.spireUtilitiesVerified=true
            surface.beginTouch("verified-cancel",at:cancel,time:now+0.02)
            assert(pad.sample.buttons & 0x2000 != 0,"Verified Cancel did not emit B")
            surface.endTouch("verified-cancel",at:cancel,cancelled:false,time:now+0.03)
            try await Task.sleep(nanoseconds:120_000_000)
            assert(pad.sample == GamepadSample())
            surface.beginTouch("verified-map",at:map,time:ProcessInfo.processInfo.systemUptime)
            assert(pad.sample.buttons & 0x20 != 0,"Verified Map did not emit View")
            surface.endTouch("verified-map",at:map,cancelled:false,time:ProcessInfo.processInfo.systemUptime)
            try await Task.sleep(nanoseconds:120_000_000)
            assert(pad.sample == GamepadSample())
            now=ProcessInfo.processInfo.systemUptime
            let pointer=CGPoint(x:surface.bounds.midX,y:surface.bounds.midY),moved=CGPoint(x:pointer.x+30,y:pointer.y)
            let eventStart=PackBoundarySpy.pointer.count
            surface.beginTouch("card-drag",at:pointer,time:now)
            surface.moveTouch("card-drag",to:moved,time:now+0.01)
            assert(PackBoundarySpy.pointer.dropFirst(eventStart).contains{$0.2 == 2},"Direct card drag failed")
            let heldEvents=PackBoundarySpy.pointer.count
            store.setControllerFallback(true)
            assert(!store.controllerFallback && PackBoundarySpy.pointer.count == heldEvents,"Fallback released a card drag")
            let cancelStart=PackBoundarySpy.pointer.count
            surface.beginTouch("cancel-drag",at:cancel,time:now+0.02)
            assert(PackBoundarySpy.pointer.dropFirst(cancelStart).first?.2 == 8,"Cancel drag must press right before left release")
            assert(pad.sample.buttons & 0x2000 == 0,"Active card drag also emitted controller B")
            assert(BCDTableInputActivity.cancelPending && BCDTableInputActivity.busy)
            let pendingEvents=PackBoundarySpy.pointer.count
            surface.beginTouch("pending-map",at:map,time:now+0.03)
            surface.endTouch("pending-map",at:map,cancelled:false,time:now+0.04)
            surface.beginTouch("pending-cancel",at:cancel,time:now+0.03)
            surface.endTouch("pending-cancel",at:cancel,cancelled:false,time:now+0.04)
            store.setControllerFallback(true);store.beginEditingControls()
            assert(!store.controllerFallback && !store.editing && pad.sample == GamepadSample(),"Pending cancellation allowed native input or a mode change")
            assert(PackBoundarySpy.pointer.count == pendingEvents,"Pending cancellation was interrupted or restarted")
            try await Task.sleep(nanoseconds:120_000_000)
            let cancelled=Array(PackBoundarySpy.pointer.dropFirst(cancelStart))
            assert(cancelled.count >= 3 && cancelled[0].2 == 8 && cancelled[1].2 == 4 && cancelled[2].2 == 16)
            assert(!BCDTableInputActivity.busy)
            surface.endTouch("card-drag",at:moved,cancelled:false,time:now+0.2)
            surface.endTouch("cancel-drag",at:cancel,cancelled:false,time:now+0.2)
            surface.clear()
            GamepadInput.packControllerSession=true;GamepadInput.packKeyboardMouseSession=false
            store.setControllerFallback(true);assert(store.controllerFallback && store.pack == retained)
            pad.configurePack(enabled:true,accepting:true,calibration:.init())
            let owner=UUID();pad.packTouch(owner:owner,value:BCDControllerFallbackActions.sample("A"));assert(pad.sample.buttons & 0x1000 != 0)
            store.setControllerFallback(false);assert(!store.controllerFallback && pad.sample == GamepadSample() && store.pack == retained)
            let after=try Data(contentsOf:url);assert(after == bytes,"Fallback overwrote personal layout")
            GamepadInput.packKeyboardMouseSession=true;store.setControllerFallback(true)
            assert(!store.controllerFallback,"Mouse-only session silently changed enumeration")
            GamepadInput.packKeyboardMouseSession=false
            for _ in 0..<20 {
                store.setControllerFallback(true);store.setControllerFallback(false)
                assert(!store.controllerFallback && pad.sample == GamepadSample() && store.pack == retained)
            }
        }
    }
    for (action,icon) in [("forward","up"),("back","down"),("left","left"),("right","right")] {
        assert(BCDPackCatalog.inscryptionArrowIcon(action:action,icon:"bcd."+icon) == "bcd.inscryption."+icon)
        assert(BCDPackCatalog.inscryptionArrowIcon(action:action,icon:"custom-player-icon") == "custom-player-icon")
    }
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    try Data("PASS: all nine title profiles drag and pinch through production UIKit editor; phone/pad independent, exact reload preservation, no game input; Spire no Inspect and retains controller enumeration.".utf8).write(to:folder.appendingPathComponent("all-title-editing-regression.txt"))
    try Data("PASS: controller fallback independent native owners, cancel/focus/background/resize/removal; Spire verified B/View, ordered drag cancellation and pending cancellation exclusion; A emission and repeated store transitions without profile writes; mouse-only session refused without enumeration mutation. SwiftUI callback ordering and guest menu behavior require device testing.".utf8).write(to:folder.appendingPathComponent("controller-fallback-regression.txt"))
}
