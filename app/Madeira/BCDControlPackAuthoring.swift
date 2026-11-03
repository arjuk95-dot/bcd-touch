// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001: reusable, data-only authoring. No game binding is inferred here.
import Foundation

enum BCDPackCatalog {
    struct Icon: Identifiable { var id: String; var label: String }
    static let icons: [Icon] = [
        ("scope", "Aim"), ("burst", "Shoot"), ("figure.fencing", "Sword / attack"), ("capsule.portrait", "Ammunition"), ("bolt", "Attack"), ("shield", "Block / parry"),
        ("hand.tap", "Use"), ("bag", "Inventory"), ("map", "Map"), ("pause", "Pause"),
        ("arrow.up", "Jump"), ("figure.walk", "Move"), ("figure.run", "Sprint"), ("figure.stand", "Stance"),
        ("sparkles", "Spell"), ("flame", "Special"), ("cross.case", "Heal"), ("heart", "Health"),
        ("arrow.clockwise", "Reload"), ("arrow.left.arrow.right", "Cycle"), ("arrow.up.arrow.down", "Change"),
        ("circle.grid.2x2", "Actions"), ("checkmark", "Confirm"), ("xmark", "Cancel"), ("text.bubble", "Dialogue"),
        ("eye", "View"), ("camera", "Camera"), ("binoculars", "Inspect"), ("flashlight.on.fill", "Light"),
        ("car", "Vehicle"), ("speedometer", "Accelerate"), ("stop.circle", "Brake"), ("arrow.turn.up.left", "Steer"),
        ("airplane", "Flight"), ("gearshape", "Settings"), ("person.2", "Companion"), ("flag", "Objective"),
        ("magnifyingglass", "Search"), ("cursorarrow", "Pointer"), ("keyboard", "Keyboard"),
        ("a.circle", "A"), ("b.circle", "B"), ("x.circle", "X"), ("y.circle", "Y")
    ].map { Icon(id: $0.0, label: $0.1) }
    static let genres: [(String, String)] = [
        ("first-person", "First-person / shooter"), ("third-person", "Third-person / action RPG"),
        ("side-scroller", "Platformer / side-scroller"), ("racing", "Driving / racing"),
        ("strategy", "Strategy / adventure")
    ]
    static let buttons = ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L3", "R3", "Menu", "View", "D↑", "D↓", "D←", "D→"]
    static func addableOutputs(mode: String) -> [String] {
        if mode == "controller" { return ["LT", "RT", "LB", "RB"] + buttons.filter { !["LT", "RT", "LB", "RB"].contains($0) } }
        return ["mouse:left", "mouse:right", "mouse:middle", "mouse:wheelUp", "mouse:wheelDown"] + keys.map { "key:\($0.0)" }
    }
    static let keys: [(Int, String)] = {
        var result: [(Int, String)] = [(8,"Backspace"),(9,"Tab"),(13,"Enter"),(16,"Shift"),(17,"Ctrl"),(18,"Alt"),(27,"Esc"),(32,"Space"),
            (33,"Page Up"),(34,"Page Down"),(35,"End"),(36,"Home"),(37,"Left"),(38,"Up"),(39,"Right"),(40,"Down"),(45,"Insert"),(46,"Delete")]
        for code in 48...57 { result.append((code, String(UnicodeScalar(code)!))) }
        for code in 65...90 { result.append((code, String(UnicodeScalar(code)!))) }
        for code in 112...135 { result.append((code, "F\(code - 111)")) }
        return result
    }()
    static func keyCodes(_ output: String) -> [Int32]? {
        let values: [Substring]
        if output.hasPrefix("key:") { values = [output.dropFirst(4)] }
        else if output.hasPrefix("keys:") { values = output.dropFirst(5).split(separator: "+", omittingEmptySubsequences: false) }
        else { return nil }
        guard (output.hasPrefix("keys:") ? (2...4).contains(values.count) : values.count == 1),
              values.allSatisfy({ !$0.isEmpty && $0.count <= 3 && $0.allSatisfy { $0.isASCII && $0.isNumber } }) else { return nil }
        let codes = values.compactMap { Int32($0) }
        guard codes.count == values.count, codes.allSatisfy({ (1...255).contains($0) }), Set(codes).count == codes.count else { return nil }
        return codes
    }
    static func outputLabel(_ value: String) -> String {
        if let codes = keyCodes(value) {
            return codes.map { c in keys.first { $0.0 == Int(c) }?.1 ?? "VK \(c)" }.joined(separator: "+")
        }
        return ["mouse:left":"Left click", "mouse:right":"Right click", "mouse:middle":"Middle click", "mouse:wheelUp":"Wheel up", "mouse:wheelDown":"Wheel down"][value] ?? value
    }
    static func validOutput(_ value: String, mode: String, version: Int) -> Bool {
        if mode == "controller" { return BCDControlPack.padOutputs.contains(value) }
        if let _ = keyCodes(value) { return version >= 2 || value.hasPrefix("key:") }
        return ["mouse:left", "mouse:right"].contains(value) || (version >= 2 && ["mouse:middle", "mouse:wheelUp", "mouse:wheelDown"].contains(value))
    }
}

enum BCDPackAuthoring {
    /// Templates expose real outputs with honest raw labels, never guessed gameplay meanings.
    static func preset(identity: BCDControlPack.Identity, title: String, genre: String, mode: String) -> BCDControlPack {
        let controller = mode == "controller"
        let platformer = genre == "side-scroller"
        let outputs = controller ? ["LS", "RS"] + BCDPackCatalog.buttons :
            (platformer ? ["key:38", "key:40", "key:37", "key:39", "key:90", "key:88", "key:67", "key:86", "key:16", "key:27", "key:13", "key:9"] :
            ["key:87", "key:83", "key:65", "key:68", "mouse:left", "mouse:right", "key:32", "key:69", "key:16", "key:27", "key:9", "mouse:wheelUp", "mouse:wheelDown"])
        var actions = outputs.enumerated().map { i, output in
            BCDControlPack.Action(id: "preset-\(i)", label: BCDPackCatalog.outputLabel(output),
                icon: output == "LS" ? "figure.walk" : (output == "RS" ? "scope" : "circle"), output: output,
                behavior: output.contains("wheel") || ["Menu", "View", "key:27", "key:9"].contains(output) ? "tap" : "hold",
                evidence: "manual-preset", contexts: ["onFoot", "menu", "vehicle"])
        }
        let primary = controller ? "RT" : (platformer ? "key:90" : (genre == "racing" ? "key:87" : "mouse:left"))
        if let i = actions.firstIndex(where: { $0.output == primary }) {
            actions[i].icon = genre == "racing" ? "speedometer" : (genre == "strategy" ? "cursorarrow" : "burst")
        }
        var p = BCDControlPack(version: 2, id: "manual-\(genre)-\(mode)", title: title, identity: identity, inputMode: mode,
            aim: .init(), actions: actions,
            phone: .init(aimRect: .init(x: 0.34, y: 0.18, width: 0.40, height: 0.55), controls: []),
            pad: .init(aimRect: .init(x: 0.30, y: 0.16, width: 0.45, height: 0.58), controls: []),
            gestures: [], radial: [], contexts: ["onFoot", "menu", "vehicle"],
            evidence: [.init(id: "manual-preset", source: "BCD built-in authoring preset", detail: "Raw input outputs only. Genre changes reach and emphasis; it does not establish the game's bindings. Assign meanings after checking the game's controls or using researched generation.")],
            unresolved: ["Check this game's bindings and input support. Template labels are raw outputs, not verified gameplay actions.", "Select onFoot, menu or vehicle explicitly. No game state is inferred."])
        for isPad in [false, true] {
            var layout = isPad ? p.pad : p.phone
            func add(_ output: String, _ x: Double, _ y: Double, _ r: Double, _ role: String = "button") {
                guard let a = actions.first(where: { $0.output == output }) else { return }
                layout.controls.append(.init(id: a.id, action: a.id, role: role, x: x, y: y, radius: r, hitRadius: r, opacity: 0.35))
            }
            if controller {
                add("LS", isPad ? 0.12 : 0.14, isPad ? 0.84 : 0.80, isPad ? 0.09 : 0.12, "move")
                let primaryOutput = ["side-scroller", "third-person", "strategy"].contains(genre) ? "A" : "RT"
                add(primaryOutput, isPad ? 0.90 : 0.88, isPad ? 0.78 : (genre == "side-scroller" ? 0.78 : 0.70), isPad ? 0.08 : 0.10,
                    genre == "first-person" ? "fireAim" : "button")
                let priority = genre == "racing" ? ["LT","A","B","X","LB"] : (genre == "first-person" ? ["LT","A","B","X","RB"] : ["X","B","Y","RT","RB"])
                let remaining = actions.filter { !["LS", "RS", primaryOutput, "Menu", "View"].contains($0.output) }.sorted {
                    (priority.firstIndex(of: $0.output) ?? 99) < (priority.firstIndex(of: $1.output) ?? 99)
                }
                for (i, a) in remaining.prefix(5).enumerated() {
                    let positions = [(0.94,0.41),(0.81,0.91),(0.95,0.91),(0.82,0.34),(0.08,0.30)]
                    add(a.output, positions[i].0, positions[i].1, 0.045)
                }
                p.radial = remaining.dropFirst(5).map(\.id)
                add("Menu",0.57,0.075,0.035); add("View",0.43,0.075,0.035)
            } else {
                let directions = platformer ? ["key:38","key:40","key:37","key:39"] : ["key:87","key:83","key:65","key:68"]
                for (i, key) in directions.enumerated() where genre != "racing" {
                    let positions = [(0.14,0.66),(0.14,0.90),(0.065,0.79),(0.24,0.79)]
                    add(key,positions[i].0,positions[i].1,0.045)
                }
                if genre == "racing" {
                    add("key:65",0.07,0.79,0.06); add("key:68",isPad ? 0.21 : 0.25,0.79,0.06)
                    add("key:87",0.89,isPad ? 0.78 : 0.70,isPad ? 0.08 : 0.10)
                    add("key:83",0.94,0.40,0.055); add("key:32",0.95,0.91,0.045); add("key:69",0.81,0.91,0.045)
                    add("key:27",0.57,0.075,0.035); add("key:9",0.43,0.075,0.035)
                } else if platformer {
                    add("key:90",0.88,isPad ? 0.78 : 0.72,isPad ? 0.08 : 0.10)
                    add("key:88",0.95,0.91,0.05); add("key:67",0.94,0.40,0.045); add("key:86",0.81,0.91,0.045)
                    add("key:27",0.57,0.075,0.035); add("key:13",0.43,0.075,0.035)
                } else {
                    add("mouse:left",0.89,isPad ? 0.78 : 0.70,isPad ? 0.08 : 0.10,genre == "first-person" ? "fireAim" : "button")
                    add("mouse:right",0.94,0.40,0.045); add("key:32",0.94,0.91,0.045); add("key:69",0.81,0.91,0.045)
                    add("key:27",0.57,0.075,0.035); add("key:9",0.43,0.075,0.035)
                }
                p.radial = actions.filter { !layout.controls.map(\.action).contains($0.id) }.map(\.id)
            }
            layout.controls.append(.init(id: "occasional", action: p.radial.first ?? actions[0].id, role: "radial", x: 0.48, y: 0.91, radius: 0.045, hitRadius: 0.045, opacity: 0.30))
            if isPad { p.pad = layout } else { p.phone = layout }
        }
        return p
    }

    /// Pick a free acquisition region in both layouts; never conceal an oversized hit target.
    static func addButton(to original: BCDControlPack, context: String, output: String? = nil) throws -> BCDControlPack {
        var p = original
        let binding = output ?? (p.inputMode == "controller" ? "A" : "key:32")
        guard BCDPackCatalog.validOutput(binding, mode: p.inputMode, version: 2), !["LS", "RS"].contains(binding) else {
            throw BCDControlPack.Invalid.reason("Choose a button, key or mouse input available in this mode.")
        }
        if p.inputMode == "keyboardMouse" { p.version = max(p.version, 2) }
        let id = "personal-" + UUID().uuidString.lowercased()
        let behavior = ["Menu", "View"].contains(binding) || binding.hasPrefix("mouse:wheel") ? "tap" : "hold"
        p.actions.append(.init(id: id, label: BCDPackCatalog.outputLabel(binding), icon: "hand.tap", output: binding, behavior: behavior, evidence: "player-binding", contexts: [context]))
        ensurePlayerEvidence(&p)
        for pad in [false, true] {
            var layout = pad ? p.pad : p.phone
            let r = 0.04
            let candidates = [0.08,0.20,0.32,0.44,0.56,0.68,0.80,0.92].flatMap { x in [0.07,0.91,0.32,0.45,0.58].map { (x,$0) } }
            let point = candidates.first(where: { x, y in
                let a = layout.aimRect
                guard x+r <= a.x || x-r >= a.x+a.width || y+r <= a.y || y-r >= a.y+a.height else { return false }
                return layout.controls.allSatisfy { c in
                    let sameContext = p.actions.first(where: { $0.id == c.action })?.contexts.contains(context) ?? true
                    return !sameContext || abs(x-c.x) >= r+c.hitRadius+0.01 || abs(y-c.y) >= r+c.hitRadius+0.01
                }
            }) ?? (0.5, 0.5) // Personal placement remains possible when all suggested free slots are occupied.
            layout.controls.append(.init(id: id, action: id, role: "button", x: point.0, y: point.1, radius: r, hitRadius: r, opacity: 0.4))
            if pad { p.pad = layout } else { p.phone = layout }
        }
        try p.validate(placement: .personal); return p
    }
    static func ensurePlayerEvidence(_ p: inout BCDControlPack) {
        if !p.evidence.contains(where: { $0.id == "player-binding" }) {
            p.evidence.append(.init(id: "player-binding", source: "Player's touch editor", detail: "Explicit personal assignment. This records a player edit, not independently verified game defaults."))
        }
    }
    static func removeAction(_ id: String, from p: inout BCDControlPack) {
        p.actions.removeAll { $0.id == id }; p.phone.controls.removeAll { $0.action == id && $0.role != "radial" }
        p.pad.controls.removeAll { $0.action == id && $0.role != "radial" }
        p.radial.removeAll { $0 == id }; p.gestures.removeAll { $0.action == id }
    }

    /// Three-way merge: untouched generated fields update; explicit edits survive. Legacy edits keep old behavior.
    static func merge(base: BCDControlPack, personal: BCDControlPack, baseline: BCDControlPack?) throws -> BCDControlPack {
        var p = base
        guard personal.inputMode == base.inputMode else { throw BCDControlPack.Invalid.reason("Personal bindings use a different input mode; select the matching preset to edit them.") }
        for pad in [false, true] {
            var layout = pad ? p.pad : p.phone
            let edited = pad ? personal.pad : personal.phone
            let old = baseline.map { pad ? $0.pad : $0.phone }
            if let old {
                let deleted = Set(old.controls.map(\.id)).subtracting(edited.controls.map(\.id))
                layout.controls.removeAll { deleted.contains($0.id) }
                if edited.aimRect != old.aimRect { layout.aimRect = edited.aimRect }
            }
            for c in edited.controls {
                let before = old?.controls.first { $0.id == c.id }
                if let i = layout.controls.firstIndex(where: { $0.id == c.id }) {
                    let changedSpace = before == nil || c.coordinateSpace != before!.coordinateSpace
                    if changedSpace { layout.controls[i].coordinateSpace = c.coordinateSpace }
                    if changedSpace || c.x != before!.x { layout.controls[i].x = c.x }
                    if changedSpace || c.y != before!.y { layout.controls[i].y = c.y }
                    if before == nil || c.radius != before!.radius { layout.controls[i].radius = c.radius }
                    if before == nil || c.hitRadius != before!.hitRadius { layout.controls[i].hitRadius = c.hitRadius }
                    if before == nil || c.opacity != before!.opacity { layout.controls[i].opacity = c.opacity }
                    if let before {
                        if c.action != before.action { layout.controls[i].action = c.action }
                        if c.role != before.role { layout.controls[i].role = c.role }
                    } else if ["button","fireAim"].contains(c.role), ["button","fireAim"].contains(layout.controls[i].role) { layout.controls[i].role = c.role }
                } else if (old != nil && before == nil) || c.id == "left-duplicate" { layout.controls.append(c) }
            }
            if let old, edited.controls.map(\.id) != old.controls.map(\.id) {
                let byID = Dictionary(uniqueKeysWithValues: layout.controls.map { ($0.id, $0) })
                let personalIDs = Set(edited.controls.map(\.id))
                layout.controls = edited.controls.compactMap { byID[$0.id] } + layout.controls.filter { !personalIDs.contains($0.id) }
            }
            if pad { p.pad = layout } else { p.phone = layout }
        }
        if let old = baseline {
            let deleted = Set(old.actions.map(\.id)).subtracting(personal.actions.map(\.id))
            for id in deleted { removeAction(id, from: &p) }
            for a in personal.actions {
                let before = old.actions.first { $0.id == a.id }
                if let i = p.actions.firstIndex(where: { $0.id == a.id }), let before {
                    if a.label != before.label { p.actions[i].label = a.label }
                    if a.icon != before.icon { p.actions[i].icon = a.icon }
                    if a.behavior != before.behavior { p.actions[i].behavior = a.behavior }
                    if a.contexts != before.contexts { p.actions[i].contexts = a.contexts }
                    if a.output != before.output { p.actions[i].output = a.output; p.actions[i].evidence = "player-binding" }
                } else if before == nil { p.actions.append(a) }
            }
            if personal.radial != old.radial { p.radial = personal.radial }
            if personal.gestures != old.gestures { p.gestures = personal.gestures }
            if personal.contexts != old.contexts { p.contexts = personal.contexts }
            if personal.aim.sensitivity != old.aim.sensitivity { p.aim.sensitivity = personal.aim.sensitivity }
            if personal.aim.vertical != old.aim.vertical { p.aim.vertical = personal.aim.vertical }
            if personal.aim.invertY != old.aim.invertY { p.aim.invertY = personal.aim.invertY }
            if personal.aim.deadZone != old.aim.deadZone { p.aim.deadZone = personal.aim.deadZone }
            if personal.aim.fullSpeed != old.aim.fullSpeed { p.aim.fullSpeed = personal.aim.fullSpeed }
            for e in personal.evidence where !p.evidence.contains(where: { $0.id == e.id }) { p.evidence.append(e) }
            p.version = max(p.version, personal.version)
            ensurePlayerEvidence(&p)
        } else { p.aim = personal.aim }
        try p.validate(for: base.identity, placement: .personal); return p
    }
}
