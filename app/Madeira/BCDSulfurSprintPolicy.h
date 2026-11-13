// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef BCD_SULFUR_SPRINT_POLICY_H
#define BCD_SULFUR_SPRINT_POLICY_H
#include <math.h>
typedef struct { int active, emitted, dwelling; double lastTime, dwellStart; } BCDSulfurSprintState;
static inline int BCDSulfurSprintCancel(BCDSulfurSprintState *s) {
    if(s) { s->active=0; s->emitted=0; s->dwelling=0; }
    return 0; // NEVER an exit/off pulse.
}
static inline int BCDSulfurSprintBegin(BCDSulfurSprintState *s,double now,int allowed) {
    if(!s) return 0;
    BCDSulfurSprintCancel(s);
    if(!allowed || !isfinite(now)) return 0;
    s->active=1; s->lastTime=now; s->dwellStart=now;
    return 0;
}
// Seconds; x right+, y down+, displacement / floating-pad radius, NOT clamped LS.
// Returns 1 once per contact: request one ordinary L3 pulse, NOT known guest state.
static inline int BCDSulfurSprintUpdate(BCDSulfurSprintState *s,double x,double y,double now,int allowed) {
    if(!s || !s->active) return 0;
    if(!allowed || !isfinite(x) || !isfinite(y) || !isfinite(now) || now<s->lastTime)
        return BCDSulfurSprintCancel(s);
    s->lastTime=now;
    if(s->emitted) return 0;
    double forward=-y;
    if(!(forward>1.15 && fabs(x)<=forward*0.45)) { s->dwelling=0; return 0; }
    if(!s->dwelling) { s->dwelling=1; s->dwellStart=now; }
    if(now-s->dwellStart>=0.120) { s->emitted=1; s->dwelling=0; return 1; }
    return 0;
}
// Feed Update on timer with latest displacement for stationary dwell. Caller owns
// one movement contact. Lift/menu/focus/cancel: neutral LS, release L3 through the
// normal pulse lifecycle, Cancel; never send an assumed off pulse. Exact game IL
// CalculateMovementVelocity clears its latch on zero calculated direction, but a
// host neutral update is NOT proof the guest processed it before another contact.
// Crouch/disable/external inputs may reset/change guest state. No same-contact
// rearming after those events. Runtime must gate reviewed build/mode/configuration:
// Always mode has inverse L3 semantics; this policy does not verify mode or state.
#endif
