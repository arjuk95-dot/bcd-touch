// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001, 2026-11-01. Data only; no scripts, executable artwork or inferred state detection.
import Foundation

struct BCDControlPack: Codable, Equatable {
    struct Identity: Codable, Equatable {
        var executable: String
        var storeID: String
        var edition: String
        var build: String
        var bindingDigest: String
    }
    struct Evidence: Codable, Equatable { var id: String; var source: String; var detail: String }
    struct Action: Codable, Equatable {
        var id: String; var label: String; var icon: String
        var output: String; var behavior: String; var evidence: String
        var contexts: [String]
    }
    struct Control: Codable, Equatable {
        var id: String; var action: String; var role: String
        var x: Double; var y: Double; var radius: Double; var hitRadius: Double; var opacity: Double
        // Existing/generated controls retain safe-area anchors. Personal drags can use the whole display.
        var coordinateSpace: String? = nil
        var slideToAction: String? = nil
        var labelPlacement: String? = nil
        var showLabel: Bool? = nil
    }
    struct Layout: Codable, Equatable {
        struct Rect: Codable, Equatable { var x: Double; var y: Double; var width: Double; var height: Double }
        var aimRect: Rect
        var controls: [Control]
        var movementRect: Rect? = nil
    }
    struct Gesture: Codable, Equatable { var kind: String; var action: String }
    var version: Int
    var id: String
    var title: String
    var identity: Identity
    var inputMode: String
    var aim: BCDMouseJoystick.Calibration
    var actions: [Action]
    var phone: Layout
    var pad: Layout
    var gestures: [Gesture]
    var radial: [String]
    var contexts: [String]
    var evidence: [Evidence]
    var unresolved: [String]
    var lookMode: String? = nil
    /// Version 4 is opt-in. Older packs retain their original touch routing.
    struct DigitalMovement: Codable, Equatable {
        var left: String; var right: String; var up: String; var down: String
        var deadZone: Double = 0.18
        var flightThreshold: Double = 0.35
        var downThreshold: Double = 0.78
        var hysteresis: Double = 0.06
    }
    struct CursorControls: Codable, Equatable {
        var fire: String; var inventory: String; var pause: String; var throwAction: String
        var primaryClick: String; var secondaryClick: String
        var firingMultiplier: Double = 1
        var radialX: Double = 0.75; var radialY: Double = 0.5; var radialRadius: Double = 0.28
    }
    var digitalMovement: DigitalMovement? = nil
    var cursorControls: CursorControls? = nil

    static let padOutputs: Set<String> = ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L3", "R3", "Menu", "View", "D↑", "D↓", "D←", "D→", "LS", "RS"]
    enum Invalid: Error, CustomStringConvertible {
        case reason(String)
        var description: String { if case .reason(let s) = self { return s }; return "Invalid pack" }
    }
    enum Placement { case generated, personal }
    func validate(for expected: Identity? = nil, placement: Placement = .generated) throws {
        func require(_ ok: Bool, _ reason: String) throws { if !ok { throw Invalid.reason(reason) } }
        func text(_ s: String) -> Bool { !s.isEmpty && s.utf8.count <= 256 && !s.unicodeScalars.contains { $0.value < 32 } }
        try require([1, 2, 3, 4].contains(version), "Unsupported pack version")
        try require(text(id) && text(title), "Missing name")
        try require(expected == nil || identity == expected, "Game/build/bindings mismatch")
        for s in [identity.executable, identity.storeID, identity.edition, identity.build, identity.bindingDigest] { try require(text(s), "Incomplete identity") }
        try require(["controller", "keyboardMouse"].contains(inputMode), "Unknown input mode")
        try require(lookMode == nil || (version >= 3 && ["none", "mouseJoystick", "relativeMouse"].contains(lookMode!)), "Unknown or unsupported look mode")
        try require(lookMode != "mouseJoystick" || inputMode == "controller", "Mouse Joystick requires controller mode")
        try require(lookMode != "relativeMouse" || inputMode == "keyboardMouse", "Relative mouse requires keyboard/mouse mode")
        try require(!contexts.isEmpty && contexts.count <= 8 && Set(contexts).count == contexts.count && contexts.allSatisfy(text), "Invalid contexts")
        try require(!actions.isEmpty && actions.count <= 64 && Set(actions.map(\.id)).count == actions.count, "Duplicate/too many actions")
        try require(evidence.count <= 128 && !evidence.isEmpty && Set(evidence.map(\.id)).count == evidence.count, "Invalid evidence")
        try require(evidence.allSatisfy { text($0.id) && text($0.source) && !$0.detail.isEmpty && $0.detail.utf8.count <= 4096 }, "Empty evidence")
        try require(unresolved.count <= 64 && unresolved.allSatisfy(text), "Invalid unresolved actions")
        for a in actions {
            try require(text(a.id) && text(a.label) && text(a.icon), "Missing action metadata")
            try require(a.icon.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }, "Invalid local icon name")
            if a.icon.hasPrefix("bcd.") { try require(version >= 3 && BCDPackCatalog.customIconNames.contains(a.icon), "Unknown local outline icon") }
            let outputOK = BCDPackCatalog.validOutput(a.output, mode: inputMode, version: version)
            try require(outputOK, "Output unavailable in selected input mode")
            try require(["hold", "tap", "release"].contains(a.behavior) || (version >= 3 && a.behavior == "toggle"), "Unknown action behavior")
            try require(!a.output.hasPrefix("mouse:wheel") || ["tap", "release"].contains(a.behavior), "Wheel actions must tap or release")
            if a.behavior == "toggle" {
                try require(!["LS", "RS"].contains(a.output) && !radial.contains(a.id) && !gestures.contains { $0.action == a.id }, "Toggle actions require a direct button")
            }
            try require(!a.contexts.isEmpty && Set(a.contexts).isSubset(of: Set(contexts)), "Unknown action context")
            try require(evidence.contains { $0.id == a.evidence }, "Binding has no evidence")
        }
        let ids = Set(actions.map(\.id))
        var capabilityActions = Set<String>()
        if let cursor = cursorControls {
            try require(version >= 4 && inputMode == "keyboardMouse" && lookMode == "relativeMouse", "Cursor capability requires version 4 keyboard/mouse relative mode")
            guard let move = digitalMovement else { throw Invalid.reason("Cursor capability requires digital movement") }
            capabilityActions = Set([cursor.fire,cursor.inventory,cursor.pause,cursor.throwAction,cursor.primaryClick,cursor.secondaryClick,move.left,move.right,move.up,move.down])
            try require(capabilityActions.isSubset(of: ids), "Unknown cursor/movement action")
            try require([move.deadZone,move.flightThreshold,move.downThreshold,move.hysteresis,cursor.firingMultiplier,cursor.radialX,cursor.radialY,cursor.radialRadius].allSatisfy(\.isFinite), "Nonfinite cursor settings")
            try require((0.05...0.6).contains(move.deadZone) && (0.15...0.9).contains(move.flightThreshold) && (0.4...1.5).contains(move.downThreshold) && (0.01...0.14).contains(move.hysteresis) && move.hysteresis < min(move.deadZone,move.flightThreshold), "Invalid digital movement thresholds")
            try require((0.1...3).contains(cursor.firingMultiplier) && (0...1).contains(cursor.radialX) && (0...1).contains(cursor.radialY) && (0.18...0.4).contains(cursor.radialRadius), "Invalid cursor/radial calibration")
            try require(radial.count == 8 && Set(radial).count == 8, "Equipment radial needs eight stable slots")
            for id in [move.left,move.right,move.up,move.down] { try require(actions.first { $0.id == id }?.output.hasPrefix("key:") == true, "Digital movement must use keyboard keys") }
            try require(actions.first { $0.id == cursor.fire }?.output == "mouse:left" && actions.first { $0.id == cursor.fire }?.behavior == "hold", "Cursor fire must hold primary mouse")
            try require(actions.first { $0.id == cursor.primaryClick }?.output == "mouse:left" && actions.first { $0.id == cursor.secondaryClick }?.output == "mouse:right", "Pointer click bindings must use mouse buttons")
            try require(radial.allSatisfy { id in actions.contains { $0.id == id && $0.output.hasPrefix("key:") && $0.behavior == "tap" } }, "Equipment slots require direct tapped keys")
        } else { try require(digitalMovement == nil, "Digital movement requires cursor capability") }
        try require(radial.count <= 8 && radial.allSatisfy { ids.contains($0) }, "Unknown radial action")
        try require(gestures.count <= 4 && Set(gestures.map(\.kind)).count == gestures.count && gestures.allSatisfy { ["swipeUp", "swipeDown", "swipeLeft", "swipeRight"].contains($0.kind) && ids.contains($0.action) }, "Unknown gesture")
        for layout in [phone, pad] {
            let r = layout.aimRect
            try require([r.x, r.y, r.width, r.height].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } && r.width >= 0.25 && r.height >= 0.25 && r.x + r.width <= 1 && r.y + r.height <= 1, "Invalid reserved aim rectangle")
            if let m = layout.movementRect {
                try require(version >= 3 && [m.x, m.y, m.width, m.height].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } && m.width >= 0.1 && m.height >= 0.1 && m.x + m.width <= 1 && m.y + m.height <= 1, "Invalid floating movement area")
            }
            try require(!layout.controls.isEmpty && layout.controls.count <= 48 && Set(layout.controls.map(\.id)).count == layout.controls.count, "Invalid controls")
            for c in layout.controls {
                try require(text(c.id) && (ids.contains(c.action) || c.role == "radial"), "Unknown control action")
                try require(["button", "move", "fireAim", "radial", "gesture"].contains(c.role), "Unknown touch role")
                try require([c.x,c.y,c.radius,c.hitRadius,c.opacity].allSatisfy(\.isFinite), "Nonfinite geometry")
                try require((0...1).contains(c.x) && (0...1).contains(c.y) && (0.035...0.2).contains(c.radius) && c.hitRadius >= c.radius && c.hitRadius <= c.radius * 1.15 && (0.1...1).contains(c.opacity), "Invalid or oversized hidden hit region")
                try require(c.coordinateSpace == nil || ["safe", "screen"].contains(c.coordinateSpace!), "Unknown coordinate space")
                try require(c.coordinateSpace == nil || version >= 2, "Display anchors require pack version 2")
                try require(c.labelPlacement == nil || (version >= 3 && ["inside", "below"].contains(c.labelPlacement!)), "Invalid label placement")
                try require(c.showLabel == nil || version >= 4, "Optional labels require version 4")
                if let targetID = c.slideToAction {
                    let source = actions.first { $0.id == c.action }
                    let target = actions.first { $0.id == targetID }
                    try require(version >= 3 && c.role == "button" && source?.behavior == "toggle" && target?.behavior == "tap" && targetID != c.action, "Slide requires a toggle source and a separate tap action")
                    try require(layout.controls.contains { $0.action == targetID && $0.role == "button" }, "Slide target needs a visible button")
                    try require(Set(source?.contexts ?? []).isSubset(of: Set(target?.contexts ?? [])), "Slide target unavailable in source contexts")
                }
                if c.role == "move" { try require(cursorControls != nil ? c.action == digitalMovement?.left : actions.first { $0.id == c.action }?.output == "LS", "Invalid movement action") }
                if c.role == "fireAim" { try require(actions.first { $0.id == c.action }?.behavior == "hold", "Drag fire must hold") }
                if ["button", "fireAim", "gesture"].contains(c.role) { try require(!["LS", "RS"].contains(actions.first { $0.id == c.action }?.output ?? ""), "Axes require continuous surfaces") }
                if placement == .generated {
                    try require(c.coordinateSpace != "screen", "Generated controls must use safe-area anchors")
                    // Generation quality rule only. Personal layouts may overlap any region or control.
                    let h = c.hitRadius
                    // Cursor packs have touch-down button priority inside the touchpad;
                    // only their explicit fire region can acquire an existing swipe.
                    try require(cursorControls != nil || lookMode == "none" || c.x + h <= r.x || c.x - h >= r.x + r.width || c.y + h <= r.y || c.y - h >= r.y + r.height, "Hit region intrudes into reserved swipe area")
                }
            }
        }
        for layout in [phone, pad] {
            let reachable = Set(layout.controls.filter { $0.role != "radial" }.map(\.action) + radial + gestures.map(\.action)).union(capabilityActions)
            try require(actions.allSatisfy { reachable.contains($0.id) || (inputMode == "controller" && lookMode != "none" && $0.output == "RS") }, "Declared action has no reachable control")
        }
        try require(radial.allSatisfy { id in !["LS", "RS"].contains(actions.first { $0.id == id }?.output ?? "") } && gestures.allSatisfy { g in !["LS", "RS"].contains(actions.first { $0.id == g.action }?.output ?? "") }, "Axes cannot be pulsed")
        try require(aim.sensitivity.isFinite && (0.1...8).contains(aim.sensitivity) && aim.vertical.isFinite && (0.25...2).contains(aim.vertical) && aim.deadZone.isFinite && (0...0.4).contains(aim.deadZone) && aim.fullSpeed.isFinite && (200...3000).contains(aim.fullSpeed), "Invalid aim calibration")
    }
    static func decode(_ data: Data, for expected: Identity? = nil, placement: Placement = .generated) throws -> Self {
        guard data.count <= 262144 else { throw Invalid.reason("Pack exceeds 256 KiB") }
        let p = try JSONDecoder().decode(Self.self, from: data)
        try p.validate(for: expected, placement: placement); return p
    }
}
