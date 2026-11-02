// SPDX-License-Identifier: GPL-3.0-or-later
// WO-BCD-TOUCH-001, 2026-11-01. Original touch-fork implementation.
import Foundation

/// Velocity, never displacement from touch-down. No integrator, backlog, momentum or edge spin.
struct BCDMouseJoystick {
    struct Calibration: Codable, Equatable {
        var sensitivity: Double = 1
        var vertical: Double = 1
        var invertY: Bool = false
        var deadZone: Double = 0.18
        var fullSpeed: Double = 900 // UIKit points/second at sensitivity 1
    }
    private var lastTime: Double?
    private var activeInterval = 1.0 / 60
    private var lastDelivery: Double?
    private var deliveryInterval = 1.0 / 60
    private var expires = 0.0
    private var x = 0.0, y = 0.0
    mutating func reset() { lastTime = nil; lastDelivery = nil; activeInterval = 1.0 / 60; deliveryInterval = 1.0 / 60; expires = 0; x = 0; y = 0 }
    mutating func begin(time: Double, receivedAt: Double? = nil) {
        reset()
        let delivery = receivedAt ?? time
        if time.isFinite && delivery.isFinite { lastTime = time; lastDelivery = delivery }
    }
    mutating func move(dx: Double, dy: Double, time: Double, receivedAt: Double? = nil, calibration c: Calibration) {
        let delivery = receivedAt ?? time
        guard time.isFinite, delivery.isFinite, dx.isFinite, dy.isFinite, let previous = lastTime, time > previous,
              lastDelivery == nil || delivery >= lastDelivery! else { return }
        let gap = time - previous
        lastTime = time
        // UIKit emits no stationary samples. A fresh delta after resting must
        // still produce a fine correction, using the last active cadence.
        // Source timestamps determine velocity. Delivery timestamps are on the
        // publisher's uptime clock: UIKit may deliver old/coalesced samples.
        let dt = gap > 0.1 ? activeInterval : max(gap, 1.0 / 240)
        if gap <= 0.1 { activeInterval = min(1.0 / 30, max(1.0 / 240, gap)) }
        var vx = dx / max(dt, 1.0 / 240) * c.sensitivity / c.fullSpeed
        var vy = -dy / max(dt, 1.0 / 240) * c.sensitivity * c.vertical / c.fullSpeed * (c.invertY ? -1 : 1)
        let length = hypot(vx, vy)
        if length > 0 {
            let amplitude = c.deadZone + (1 - c.deadZone) * min(1, length)
            vx = vx / length * amplitude; vy = vy / length * amplitude
        }
        x = vx; y = vy
        if let before = lastDelivery {
            let interval = delivery - before
            if interval > 0 && interval <= 0.1 { deliveryInterval = min(1.0 / 30, max(1.0 / 240, interval)) }
        }
        lastDelivery = delivery
        // Recomputed by GamepadInput's 4 ms clock even with no physical pad or move events.
        // The main actor captures delivery BEFORE its serial queue hop. A delayed
        // queued publication still expires; queue execution never renews motion.
        expires = delivery + min(0.042, max(0.012, deliveryInterval * 1.25 + 0.004))
    }
    func sample(time: Double) -> (x: Double, y: Double) {
        guard time.isFinite, time < expires else { return (0, 0) }
        return (x, y)
    }
}
