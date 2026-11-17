#ifndef BCD_INSCRYPTION_SWIPE_POLICY_H
#define BCD_INSCRYPTION_SWIPE_POLICY_H
#include <math.h>
/* Pure end-only recognition, logical points, x-right/y-down. The caller owns
 * region eligibility and must feed coalesced samples in order, then final End.
 * Pointer is permission to retain existing tap/hold semantics, not a click.
 * No intermediate input is emitted. Lost focus/menu/multitouch must Cancel.
 * Paths unknowable between delivered samples cannot be reconstructed. */
enum {
    BCDInscryptionSwipeNone = 0, BCDInscryptionSwipePointer = 1,
    BCDInscryptionSwipeLeft = 2, BCDInscryptionSwipeRight = 3,
    BCDInscryptionSwipeUp = 4, BCDInscryptionSwipeDown = 5
};
typedef struct {
    int active, rejected, direction;
    double x, y, started, maxExcursion, maxProgress;
} BCDInscryptionSwipeState;
static inline int BCDInscryptionSwipeCancel(BCDInscryptionSwipeState *s) {
    if (s) { BCDInscryptionSwipeState empty = {0}; *s = empty; }
    return BCDInscryptionSwipeNone;
}
static inline int BCDInscryptionSwipeBegin(BCDInscryptionSwipeState *s,
                                         double x, double y, double time) {
    BCDInscryptionSwipeCancel(s);
    if (s && isfinite(x) && isfinite(y) && isfinite(time)) {
        s->active = 1; s->x = x; s->y = y; s->started = time;
    }
    return BCDInscryptionSwipeNone;
}
static inline int BCDInscryptionSwipeMove(BCDInscryptionSwipeState *s,
                                        double x, double y) {
    if (!s || !s->active || s->rejected) return BCDInscryptionSwipeNone;
    double dx = x - s->x, dy = y - s->y;
    double distance = hypot(dx, dy), ax = fabs(dx), ay = fabs(dy);
    if (!isfinite(x) || !isfinite(y) || !isfinite(distance)) {
        s->rejected = 1; return BCDInscryptionSwipeNone;
    }
    if (distance > s->maxExcursion) s->maxExcursion = distance;
    if (distance <= 8.0) {
        if (s->direction) s->rejected = 1; /* out-and-back */
        return BCDInscryptionSwipeNone;
    }
    int direction = BCDInscryptionSwipeNone;
    double progress = 0;
    if (ax >= 1.35 * ay) {
        direction = dx < 0 ? BCDInscryptionSwipeLeft : BCDInscryptionSwipeRight;
        progress = ax;
    } else if (ay >= 1.35 * ax) {
        direction = dy < 0 ? BCDInscryptionSwipeUp : BCDInscryptionSwipeDown;
        progress = ay;
    }
    /* Once outside the pointer slop, ambiguous/crossed paths fail closed.
     * Longitudinal reversal also fails closed; no directional input is safer
     * than guessing intent from a scrubbed or reversed stroke. */
    if (!direction || (s->direction && direction != s->direction) ||
        progress < s->maxProgress) {
        s->rejected = 1; return BCDInscryptionSwipeNone;
    }
    s->direction = direction;
    if (progress > s->maxProgress) s->maxProgress = progress;
    return BCDInscryptionSwipeNone;
}
static inline int BCDInscryptionSwipeEnd(BCDInscryptionSwipeState *s,
                                       double x, double y, double time,
                                       int cancelled) {
    if (!s) return BCDInscryptionSwipeNone;
    BCDInscryptionSwipeMove(s, x, y);
    int result = BCDInscryptionSwipeNone;
    double elapsed = time - s->started;
    if (s->active && !s->rejected && !cancelled && isfinite(time) &&
        isfinite(elapsed) && elapsed >= 0) {
        if (s->maxExcursion <= 8.0) result = BCDInscryptionSwipePointer;
        else if (elapsed <= 0.65 && s->direction &&
                 fmax(fabs(x - s->x), fabs(y - s->y)) >= 24.0)
            result = s->direction;
    }
    BCDInscryptionSwipeCancel(s);
    return result;
}
#endif
