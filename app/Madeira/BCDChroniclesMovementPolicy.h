// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef BCD_CHRONICLES_MOVEMENT_POLICY_H
#define BCD_CHRONICLES_MOVEMENT_POLICY_H
#include <math.h>

// Semantic directions ONLY. This does not establish a game's physical bindings.
// One state belongs to one movement contact. Coordinates are logical points,
// UIKit convention (right/down positive). The floating origin never recenters.
typedef struct { int horizontal; int crouch; } BCDChroniclesMovementOutput;
typedef struct {
    int active;
    double originX, originY, radius;
    BCDChroniclesMovementOutput output;
} BCDChroniclesMovementState;

static inline BCDChroniclesMovementOutput BCDChroniclesMovementCancel(BCDChroniclesMovementState *s) {
    BCDChroniclesMovementOutput neutral = {0, 0};
    if (s) { s->active = 0; s->output = neutral; }
    return neutral;
}
static inline BCDChroniclesMovementOutput BCDChroniclesMovementBegin(
    BCDChroniclesMovementState *s, double x, double y, double radius) {
    BCDChroniclesMovementOutput neutral = BCDChroniclesMovementCancel(s);
    if (!s || !isfinite(x) || !isfinite(y) || !isfinite(radius) || radius <= 0) return neutral;
    s->active = 1; s->originX = x; s->originY = y; s->radius = radius;
    return neutral;
}
static inline BCDChroniclesMovementOutput BCDChroniclesMovementUpdate(
    BCDChroniclesMovementState *s, double x, double y) {
    BCDChroniclesMovementOutput neutral = {0, 0};
    if (!s || !s->active) return neutral;
    double dx = (x - s->originX) / s->radius;
    double dy = (y - s->originY) / s->radius;
    if (!isfinite(x) || !isfinite(y) || !isfinite(dx) || !isfinite(dy))
        return BCDChroniclesMovementCancel(s);

    // Down requires deliberately exceeding the pad radius in a downward cone.
    // A lower release threshold smooths drift, but no timer or lift can latch it.
    // Crouch is exclusive: lateral walking resumes only after leaving this cone.
    int crouch = s->output.crouch
        ? (dy >= 0.85 && fabs(dx) <= dy * 0.80)
        : (dy >= 1.10 && fabs(dx) <= dy * 0.65);
    int horizontal = 0;
    if (!crouch) {
        if (dx >= 0.20) horizontal = 1;
        else if (dx <= -0.20) horizontal = -1;
        else if (s->output.horizontal == 1 && dx > 0.12) horizontal = 1;
        else if (s->output.horizontal == -1 && dx < -0.12) horizontal = -1;
    }
    s->output.horizontal = horizontal; s->output.crouch = crouch;
    return s->output;
}
// Integrator: apply this complete output, not additive button-down events. Lift,
// cancel, menu, focus loss, editor/context/controller change must call Cancel AND
// release its existing input owner. Never route another finger into this state.
// Feed final/coalesced samples before decisions. No upward action is emitted.
// Thresholds are reviewed defaults, not claimed device-calibrated values.
#endif
