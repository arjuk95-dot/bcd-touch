// Production method fixture. No GameController, UIKit, Wine or device is used.
import Foundation

@MainActor enum MadeiraConfig {
    static var gameSetting: String?
    static func gameValue(_ key: String) -> String? {
        precondition(key == "env.MADEIRA_PAD_EARLY_SLOT")
        return gameSetting
    }
}
@MainActor final class GCController {
    static var paired = false
    static func controllers() -> [GCController] { paired ? [GCController()] : [] }
}
@MainActor final class LogStore {
    static let shared = LogStore()
    var lines: [String] = []
    func log(_ text: String) { lines.append(text) }
}
@MainActor final class ImmediateQueue {
    func async(_ block: () -> Void) { block() }
}
@MainActor final class GamepadInput {
    static var enabled = false
    static var packKeyboardMouseSession = false
    static var touchEnabled = false
    static var configuredOptIn = false
    static func optIn(_ key: String) -> Bool {
        precondition(key == "MADEIRA_PAD_EARLY_SLOT")
        return configuredOptIn
    }
    struct TouchState { var reserved = false }
    var touchState = TouchState()
    var queue = ImmediateQueue()
    var timerUpdates = 0
    var samples = 0
    func updateTimer() { timerUpdates += 1 }
    func sample() { samples += 1 }

    // PRODUCTION_RESERVATION_METHOD
}

@main struct ReservationChecks {
    @MainActor static func main() {
        var checked = 0
        for bits in 0..<128 {
            func bit(_ index: Int) -> Bool { bits & (1 << index) != 0 }
            GamepadInput.enabled = bit(0)
            GamepadInput.packKeyboardMouseSession = bit(1)
            let force = bit(2)
            GamepadInput.configuredOptIn = bit(3)
            let touch = bit(4)
            GamepadInput.touchEnabled = bit(5)
            GCController.paired = bit(6)
            for gameSetting: String? in [nil, "0", "1", "2"] {
                MadeiraConfig.gameSetting = gameSetting
                let optedIn = force || gameSetting == "1" || GamepadInput.configuredOptIn
                let allowed = GamepadInput.enabled && !GamepadInput.packKeyboardMouseSession && optedIn
                let hasSource = (touch && GamepadInput.touchEnabled) || GCController.paired
                let expected = allowed && hasSource
                let model = GamepadInput()
                LogStore.shared.lines = []
                model.reserveSessionSlot(touchControls: touch, force: force)
                precondition(model.touchState.reserved == expected, "reservation case \(bits), \(String(describing: gameSetting))")
                precondition(model.timerUpdates == (expected ? 1 : 0) && model.samples == (expected ? 1 : 0))
                precondition(LogStore.shared.lines.count == (allowed ? 1 : 0))
                if allowed {
                    precondition(LogStore.shared.lines[0].contains(expected ? "slot=0 reserved" : "slot=0 not reserved"))
                }
                if !force {
                    let stock = GamepadInput()
                    stock.reserveSessionSlot(touchControls: touch)
                    precondition(stock.touchState.reserved == expected, "stock default changed")
                }
                checked += 1
            }
        }
        precondition(checked == 512)
        print("PASS: production session-slot reservation, 512 combinations and 256 stock-default calls")
    }
}
