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
    private var expires = 0.0
    private var x = 0.0, y = 0.0
    mutating func reset() { lastTime = nil; expires = 0; x = 0; y = 0 }
    mutating func begin(time: Double) { reset(); if time.isFinite { lastTime = time } }
    mutating func move(dx: Double, dy: Double, time: Double, calibration c: Calibration) {
        guard time.isFinite, dx.isFinite, dy.isFinite, let previous = lastTime, time > previous else { return }
        let dt = time - previous
        lastTime = time
        // A delayed event must not replay old motion after a pause.
        guard dt <= 0.1 else { x = 0; y = 0; expires = 0; return }
        var vx = dx / max(dt, 1.0 / 240) * c.sensitivity / c.fullSpeed
        var vy = -dy / max(dt, 1.0 / 240) * c.sensitivity * c.vertical / c.fullSpeed * (c.invertY ? -1 : 1)
        let length = hypot(vx, vy)
        if length > 0 {
            let amplitude = c.deadZone + (1 - c.deadZone) * min(1, length)
            vx = vx / length * amplitude; vy = vy / length * amplitude
        }
        x = vx; y = vy
        // Recomputed by GamepadInput's 4 ms clock even with no physical pad or move events.
        expires = time + min(0.025, max(0.012, dt * 1.5))
    }
    func sample(time: Double) -> (x: Double, y: Double) {
        guard time.isFinite, time < expires else { return (0, 0) }
        return (x, y)
    }
}
