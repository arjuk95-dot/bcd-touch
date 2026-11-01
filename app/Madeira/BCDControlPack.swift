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
    }
    struct Layout: Codable, Equatable {
        struct Rect: Codable, Equatable { var x: Double; var y: Double; var width: Double; var height: Double }
        var aimRect: Rect
        var controls: [Control]
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

    static let padOutputs: Set<String> = ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "L3", "R3", "Menu", "View", "D↑", "D↓", "D←", "D→", "LS", "RS"]
    enum Invalid: Error, CustomStringConvertible {
        case reason(String)
        var description: String { if case .reason(let s) = self { return s }; return "Invalid pack" }
    }
    func validate(for expected: Identity? = nil) throws {
        func require(_ ok: Bool, _ reason: String) throws { if !ok { throw Invalid.reason(reason) } }
        func text(_ s: String) -> Bool { !s.isEmpty && s.utf8.count <= 256 && !s.unicodeScalars.contains { $0.value < 32 } }
        try require(version == 1, "Unsupported pack version")
        try require(text(id) && text(title), "Missing name")
        try require(expected == nil || identity == expected, "Game/build/bindings mismatch")
        for s in [identity.executable, identity.storeID, identity.edition, identity.build, identity.bindingDigest] { try require(text(s), "Incomplete identity") }
        try require(["controller", "keyboardMouse"].contains(inputMode), "Unknown input mode")
        try require(!contexts.isEmpty && contexts.count <= 8 && Set(contexts).count == contexts.count && contexts.allSatisfy(text), "Invalid contexts")
        try require(!actions.isEmpty && actions.count <= 64 && Set(actions.map(\.id)).count == actions.count, "Duplicate/too many actions")
        try require(evidence.count <= 128 && !evidence.isEmpty && Set(evidence.map(\.id)).count == evidence.count, "Invalid evidence")
        try require(evidence.allSatisfy { text($0.id) && text($0.source) && !$0.detail.isEmpty && $0.detail.utf8.count <= 4096 }, "Empty evidence")
        try require(unresolved.count <= 64 && unresolved.allSatisfy(text), "Invalid unresolved actions")
        for a in actions {
            try require(text(a.id) && text(a.label) && text(a.icon), "Missing action metadata")
            try require(a.icon.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }, "Icons must be SF Symbol names")
            let outputOK = inputMode == "controller" ? Self.padOutputs.contains(a.output) :
                (a.output.range(of: "^key:[0-9]{1,3}$", options: .regularExpression) != nil || ["mouse:left", "mouse:right"].contains(a.output))
            try require(outputOK, "Output unavailable in selected input mode")
            try require(["hold", "tap", "release"].contains(a.behavior), "Unknown action behavior")
            try require(!a.contexts.isEmpty && Set(a.contexts).isSubset(of: Set(contexts)), "Unknown action context")
            try require(evidence.contains { $0.id == a.evidence }, "Binding has no evidence")
        }
        let ids = Set(actions.map(\.id))
        try require(radial.count <= 8 && radial.allSatisfy { ids.contains($0) }, "Unknown radial action")
        try require(gestures.count <= 4 && Set(gestures.map(\.kind)).count == gestures.count && gestures.allSatisfy { ["swipeUp", "swipeDown", "swipeLeft", "swipeRight"].contains($0.kind) && ids.contains($0.action) }, "Unknown gesture")
        for layout in [phone, pad] {
            let r = layout.aimRect
            try require([r.x, r.y, r.width, r.height].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 } && r.width >= 0.25 && r.height >= 0.25 && r.x + r.width <= 1 && r.y + r.height <= 1, "Invalid reserved aim rectangle")
            try require(!layout.controls.isEmpty && layout.controls.count <= 48 && Set(layout.controls.map(\.id)).count == layout.controls.count, "Invalid controls")
            for c in layout.controls {
                try require(text(c.id) && (ids.contains(c.action) || c.role == "radial"), "Unknown control action")
                try require(["button", "move", "fireAim", "radial", "gesture"].contains(c.role), "Unknown touch role")
                try require([c.x,c.y,c.radius,c.hitRadius,c.opacity].allSatisfy(\.isFinite), "Nonfinite geometry")
                try require((0...1).contains(c.x) && (0...1).contains(c.y) && (0.035...0.2).contains(c.radius) && c.hitRadius >= c.radius && c.hitRadius <= c.radius * 1.15 && (0.1...1).contains(c.opacity), "Invalid or oversized hidden hit region")
                if c.role == "move" { try require(actions.first { $0.id == c.action }?.output == "LS", "Movement must use LS") }
                if c.role == "fireAim" { try require(actions.first { $0.id == c.action }?.behavior == "hold", "Drag fire must hold") }
                // Conservative normalized square protects the whole reserved rectangle on either aspect ratio.
                let h = c.hitRadius
                try require(c.x + h <= r.x || c.x - h >= r.x + r.width || c.y + h <= r.y || c.y - h >= r.y + r.height, "Hit region intrudes into reserved swipe area")
            }
        }
        try require(aim.sensitivity.isFinite && (0.1...8).contains(aim.sensitivity) && aim.vertical.isFinite && (0.25...2).contains(aim.vertical) && aim.deadZone.isFinite && (0...0.4).contains(aim.deadZone) && aim.fullSpeed.isFinite && (200...3000).contains(aim.fullSpeed), "Invalid aim calibration")
    }
    static func decode(_ data: Data, for expected: Identity? = nil) throws -> Self {
        guard data.count <= 262144 else { throw Invalid.reason("Pack exceeds 256 KiB") }
        let p = try JSONDecoder().decode(Self.self, from: data)
        try p.validate(for: expected); return p
    }
}
