// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef BCD_INSCRYPTION_POLICY_H
#define BCD_INSCRYPTION_POLICY_H
// UI mode is explicitly player-selected, never inferred as guest game state.
// This policy requests a semantic action, not a guessed keyboard/controller code.
typedef struct { int explore; int firstStepConsumed; } BCDInscryptionMode;
enum { BCD_INSCRYPTION_BINDING_UNAVAILABLE=-1, BCD_INSCRYPTION_MODE_ONLY=0, BCD_INSCRYPTION_REQUEST_STEP_BACK=1 };
static inline int BCDInscryptionSwitch(BCDInscryptionMode *s,int verifiedStepBackAvailable) {
 if(!s->firstStepConsumed && !verifiedStepBackAvailable) return BCD_INSCRYPTION_BINDING_UNAVAILABLE;
 s->explore = !s->explore;
 if (!s->firstStepConsumed) { s->firstStepConsumed=1; return BCD_INSCRYPTION_REQUEST_STEP_BACK; }
 return BCD_INSCRYPTION_MODE_ONLY;
}
static inline void BCDInscryptionResync(BCDInscryptionMode *s,int explore) {
 s->explore=explore!=0;s->firstStepConsumed=1;
}
#endif
