import Foundation

func checkTouchAuthoring() throws {
    let identity = BCDControlPack.Identity(executable: "unknown-game.exe", storeID: "local", edition: "fixture", build: "unreported", bindingDigest: "fixture")
    for (genre, _) in BCDPackCatalog.genres {
        for mode in ["controller", "keyboardMouse"] {
            let p = BCDPackAuthoring.preset(identity: identity, title: "Unknown game fixture", genre: genre, mode: mode)
            try p.validate(for: identity)
            assert(!p.unresolved.isEmpty && p.actions.allSatisfy { $0.label == BCDPackCatalog.outputLabel($0.output) })
            assert(p.phone != p.pad, "Phone and pad must have independent reach geometry")
            if genre == "side-scroller" && mode == "keyboardMouse" {
                assert(p.actions.contains { $0.output == "key:90" } && p.actions.contains { $0.output == "key:88" })
                assert(!p.actions.contains { $0.output.hasPrefix("mouse:") }, "Manual platformer template must have directional/action keys")
            }
            let added = try BCDPackAuthoring.addButton(to: p, context: "onFoot")
            assert(added.actions.count == p.actions.count + 1)
            try added.validate(placement: .personal)
        }
    }
    let original = BCDPackAuthoring.preset(identity: identity, title: "Merge fixture", genre: "first-person", mode: "controller")
    var personal = try BCDPackAuthoring.addButton(to: original, context: "onFoot")
    let a = personal.actions.firstIndex { $0.output == "A" }!
    personal.actions[a].label = "Player use"; personal.actions[a].icon = "hand.tap"; personal.actions[a].output = "X"
    personal.phone.controls[0].x = 0.12; personal.aim.sensitivity = 2
    var regenerated = original
    regenerated.actions[a].label = "New researched default"
    let b = regenerated.actions.firstIndex { $0.output == "B" }!
    regenerated.actions[b].label = "Updated cancel"
    regenerated.phone.controls[0].y = 0.76; regenerated.aim.vertical = 1.2
    let merged = try BCDPackAuthoring.merge(base: regenerated, personal: personal, baseline: original)
    assert(merged.actions[a].label == "Player use" && merged.actions[a].output == "X")
    assert(merged.actions[b].label == "Updated cancel", "Untouched generated labels must update")
    assert(merged.actions.contains { $0.id.hasPrefix("personal-") })
    assert(merged.phone.controls[0].x == 0.12 && merged.phone.controls[0].y == 0.76)
    assert(merged.aim.sensitivity == 2 && merged.aim.vertical == 1.2)
    var deleted = original
    let removed = deleted.actions.first { $0.output == "RT" }!.id
    BCDPackAuthoring.removeAction(removed, from: &deleted)
    let deletedMerge = try BCDPackAuthoring.merge(base: regenerated, personal: deleted, baseline: original)
    assert(!deletedMerge.actions.contains { $0.id == removed })
    let legacy = try BCDPackAuthoring.merge(base: original, personal: personal, baseline: nil)
    assert(legacy.aim.sensitivity == 2 && legacy.phone.controls[0].x == 0.12)
    assert(legacy.actions[a].output == original.actions[a].output, "Legacy overrides must not invent binding edits")
    var free = original
    for pad in [false, true] {
        var layout = pad ? free.pad : free.phone
        let buttons = layout.controls.indices.filter { layout.controls[$0].role == "button" || layout.controls[$0].role == "fireAim" }
        for i in buttons.prefix(2) {
            layout.controls[i].x = 0.5; layout.controls[i].y = 0.5; layout.controls[i].coordinateSpace = "screen"
        }
        layout.controls[0].x = 0; layout.controls[0].y = 1; layout.controls[0].coordinateSpace = "screen"
        let first = layout.controls.removeFirst(); layout.controls.append(first)
        if pad { free.pad = layout } else { free.phone = layout }
    }
    try free.validate(placement: .personal)
    let freeData = try JSONEncoder().encode(free)
    let freeReloaded = try BCDControlPack.decode(freeData, for: identity, placement: .personal)
    assert(freeReloaded == free)
    do { try free.validate(); assertionFailure("Generated pack accepted personal placement") } catch {}
    let freeMerged = try BCDPackAuthoring.merge(base: regenerated, personal: free, baseline: original)
    assert(freeMerged.phone.controls.map(\.id) == free.phone.controls.map(\.id), "Personal overlap order lost on regeneration")
    assert(freeMerged.phone.controls.last?.coordinateSpace == "screen" && freeMerged.phone.controls.last?.x == 0 && freeMerged.phone.controls.last?.y == 1)
    assert(freeMerged.pad.controls.last?.coordinateSpace == "screen")
    let crowded = try BCDPackAuthoring.addButton(to: free, context: "onFoot")
    assert(crowded.actions.count == free.actions.count + 1)
    var invalidPersonal = free; invalidPersonal.phone.controls[0].x = .nan
    do { try invalidPersonal.validate(placement: .personal); assertionFailure("Nonfinite personal geometry accepted") } catch {}
    invalidPersonal = free; invalidPersonal.phone.controls[0].coordinateSpace = "executable"
    do { try invalidPersonal.validate(placement: .personal); assertionFailure("Unknown coordinate space accepted") } catch {}
    for value in ["key:0", "key:256", "key:-1", "key:+65", "keys:17", "keys:17+17", "keys:17+", "keys:17+65+66+67+68"] {
        assert(!BCDPackCatalog.validOutput(value, mode: "keyboardMouse", version: 2), "Accepted malformed binding: \(value)")
    }
    assert(BCDPackCatalog.keyCodes("keys:17+16+65") == [17,16,65])
    assert(!BCDPackCatalog.validOutput("keys:17+65", mode: "keyboardMouse", version: 1))
    assert(!BCDPackCatalog.validOutput("mouse:wheelUp", mode: "controller", version: 2))
    var slow = BCDMouseJoystick(), faster = BCDMouseJoystick()
    var c = BCDMouseJoystick.Calibration(); c.fullSpeed = 600
    slow.begin(time: 0); faster.begin(time: 0)
    slow.move(dx: 1, dy: 0, time: 0.02, calibration: c)
    c.sensitivity = 2; faster.move(dx: 1, dy: 0, time: 0.02, calibration: c)
    assert(faster.sample(time: 0.02).x > slow.sample(time: 0.02).x, "Unsaturated swipe response must change")
    slow.move(dx: 100, dy: 0, time: 0.04, calibration: c)
    c.sensitivity = 8; faster.move(dx: 100, dy: 0, time: 0.04, calibration: c)
    assert(slow.sample(time: 0.04).x == 1 && faster.sample(time: 0.04).x == 1, "Editor cannot exceed full stick")
    print("PASS: ten presets; personal overlap/full-screen anchors, export/import and regeneration order; generated spacing remains strict; malformed bindings/geometry rejected (host fixtures)")
}
