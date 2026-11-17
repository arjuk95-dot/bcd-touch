import Foundation
import SwiftUI
import UIKit

/// Raw native controller controls, deliberately not game-specific action guesses.
/// The caller selects/restores input mode; this view never edits a saved profile.
enum BCDControllerFallbackActions {
    static let names = ["D↑", "Y", "LB", "RB", "D←", "X", "LT", "RT", "D→", "B", "L3", "R3", "D↓", "A", "View", "Menu"]
    static func sample(_ name: String) -> GamepadSample? {
        let masks: [String: UInt16] = ["D↑":1,"D↓":2,"D←":4,"D→":8,"Menu":16,"View":32,"L3":64,"R3":128,"LB":256,"RB":512,"A":4096,"B":8192,"X":16384,"Y":32768]
        var value = GamepadSample()
        if let mask = masks[name] { value.buttons = mask }
        else if name == "LT" { value.lt = 255 }
        else if name == "RT" { value.rt = 255 }
        else { return nil }
        return value
    }
    static func symbol(_ name: String) -> String {
        switch name {
        case "D↑": return "arrowtriangle.up.fill"
        case "D↓": return "arrowtriangle.down.fill"
        case "D←": return "arrowtriangle.left.fill"
        case "D→": return "arrowtriangle.right.fill"
        case "View": return "rectangle.on.rectangle"
        case "Menu": return "line.3.horizontal"
        default: return name.lowercased() + ".button.roundedbottom.horizontal"
        }
    }
}

struct BCDControllerFallback: View {
    let accepting: Bool
    let output: (UUID, GamepadSample?) -> Void
    let close: () -> Void
    @State private var reset = UUID()
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Controller", systemImage: "gamecontroller.fill")
                Spacer()
                Button { reset = UUID(); close() } label: {
                    Label("Back to touch", systemImage: "xmark.circle.fill")
                }.accessibilityIdentifier("controller-fallback-close")
            }
            BCDControllerFallbackSurface(accepting: accepting, reset: reset, output: output)
                .frame(minHeight: 176, idealHeight: 224, maxHeight: 260)
            Text("Native controller inputs. In-game bindings and controller detection still apply.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("controller-fallback")
    }
}

private struct BCDControllerFallbackSurface: UIViewRepresentable {
    let accepting: Bool
    let reset: UUID
    let output: (UUID, GamepadSample?) -> Void
    func makeUIView(context: Context) -> BCDControllerFallbackView { BCDControllerFallbackView() }
    func updateUIView(_ view: BCDControllerFallbackView, context: Context) {
        view.configure(accepting: accepting, reset: reset, output: output)
    }
    static func dismantleUIView(_ view: BCDControllerFallbackView, coordinator: ()) { view.cancelAll() }
}

final class BCDControllerFallbackView: UIView {
    private var accepting = false
    private var reset: UUID?
    private var output: ((UUID, GamepadSample?) -> Void)?
    private var owners: [UUID: String] = [:]
    private var fingers: [ObjectIdentifier: UUID] = [:]
    private var lastSize = CGSize.zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: BCDPackFocus.didLoseFocus, object: nil)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    func configure(accepting: Bool, reset: UUID, output: @escaping (UUID, GamepadSample?) -> Void) {
        if self.accepting != accepting || self.reset != reset { cancelAll() }
        self.accepting = accepting; self.reset = reset; self.output = output
        isUserInteractionEnabled = accepting
        alpha = accepting ? 1 : 0.45
    }
    @objc private func interrupted() { cancelAll() }
    override func didMoveToWindow() { super.didMoveToWindow(); if window == nil { cancelAll() } }
    override func layoutSubviews() {
        super.layoutSubviews()
        if lastSize != bounds.size { cancelAll(); lastSize = bounds.size; setNeedsDisplay() }
    }
    func begin(owner: UUID, action: String) {
        guard accepting, let value = BCDControllerFallbackActions.sample(action) else { return }
        owners[owner] = action; output?(owner, value); setNeedsDisplay()
    }
    func end(owner: UUID) {
        if owners.removeValue(forKey: owner) != nil { output?(owner, nil); setNeedsDisplay() }
    }
    func cancelAll() {
        for owner in Array(owners.keys) { end(owner: owner) }
        fingers.removeAll()
    }
    private func cell(_ index: Int) -> CGRect {
        CGRect(x: CGFloat(index % 4) * bounds.width / 4 + 3,
               y: CGFloat(index / 4) * bounds.height / 4 + 3,
               width: max(0, bounds.width / 4 - 6), height: max(0, bounds.height / 4 - 6))
    }
    override func draw(_ rect: CGRect) {
        for (index, name) in BCDControllerFallbackActions.names.enumerated() {
            let area = cell(index)
            (owners.values.contains(name) ? UIColor.systemBlue : UIColor.secondarySystemFill).setFill()
            UIBezierPath(roundedRect: area, cornerRadius: 10).fill()
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
            // SF Symbols provide genuine controller glyphs; raw labels remain accessible.
            if let glyph = UIImage(systemName: BCDControllerFallbackActions.symbol(name), withConfiguration: config)?.withTintColor(.label, renderingMode: .alwaysOriginal) {
                glyph.draw(in: CGRect(x: area.midX-glyph.size.width/2, y: area.midY-glyph.size.height/2, width: glyph.size.width, height: glyph.size.height))
            } else {
                let text = name as NSString
                let attrs: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:18, weight:.semibold), .foregroundColor:UIColor.label]
                let size = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x:area.midX-size.width/2,y:area.midY-size.height/2),withAttributes:attrs)
            }
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard UIApplication.shared.applicationState == .active else { cancelAll(); return }
        for touch in touches {
            guard let index = BCDControllerFallbackActions.names.indices.first(where: { cell($0).contains(touch.location(in:self)) }) else { continue }
            let owner = UUID(); fingers[ObjectIdentifier(touch)] = owner
            begin(owner: owner, action: BCDControllerFallbackActions.names[index])
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let owner = fingers[ObjectIdentifier(touch)], let action = owners[owner], let index = BCDControllerFallbackActions.names.firstIndex(of:action) else { continue }
            if !cell(index).contains(touch.location(in:self)) { end(owner:owner) }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches) }
    private func finish(_ touches: Set<UITouch>) {
        for touch in touches { if let owner = fingers.removeValue(forKey:ObjectIdentifier(touch)) { end(owner:owner) } }
    }
}
