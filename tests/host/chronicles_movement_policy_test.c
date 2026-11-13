// SPDX-License-Identifier: GPL-3.0-or-later
#include "BCDChroniclesMovementPolicy.h"
#include <assert.h>
#include <float.h>
#include <stdio.h>
#include <stdint.h>
static void expect(BCDChroniclesMovementOutput o, int x, int down) {
    assert(o.horizontal == x); assert(o.crouch == down);
}
static uint32_t seed = 0x9123da7u;
static double randomPoint(void) { seed = seed * 1664525u + 1013904223u; return ((seed >> 8) % 20001) / 1000.0 - 10.0; }
int main(void) {
    BCDChroniclesMovementState s = {0};
    expect(BCDChroniclesMovementUpdate(&s, 999, 999), 0, 0);
    expect(BCDChroniclesMovementBegin(&s, 100, 200, 100), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 119, 210), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 121, 210), 1, 0);
    expect(BCDChroniclesMovementUpdate(&s, 115, 210), 1, 0);
    expect(BCDChroniclesMovementUpdate(&s, 111, 210), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 80, 210), -1, 0);
    expect(BCDChroniclesMovementUpdate(&s, 85, 210), -1, 0);
    expect(BCDChroniclesMovementUpdate(&s, 89, 210), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 70, 210), -1, 0);
    expect(BCDChroniclesMovementUpdate(&s, 130, 210), 1, 0); // immediate reversal
    expect(BCDChroniclesMovementUpdate(&s, 170, 290), 1, 0); // ordinary diagonal drift
    expect(BCDChroniclesMovementUpdate(&s, 200, 320), 1, 0); // outside down cone
    expect(BCDChroniclesMovementUpdate(&s, 100, 309), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 100, 311), 0, 1);
    expect(BCDChroniclesMovementUpdate(&s, 100, 290), 0, 1); // held hysteresis, not toggle
    expect(BCDChroniclesMovementUpdate(&s, 100, 284), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 100, 290), 0, 0); // must go deep again
    expect(BCDChroniclesMovementUpdate(&s, 100, 320), 0, 1);
    expect(BCDChroniclesMovementUpdate(&s, 210, 320), 1, 0); // exit cone, resume lateral
    expect(BCDChroniclesMovementUpdate(&s, 100, 0), 0, 0); // never Up
    expect(BCDChroniclesMovementUpdate(&s, 100, 320), 0, 1);
    expect(BCDChroniclesMovementCancel(&s), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 100, 320), 0, 0);
    expect(BCDChroniclesMovementBegin(&s, 250, 300, 50), 0, 0);
    expect(BCDChroniclesMovementUpdate(&s, 250, 300), 0, 0); // new floating origin
    expect(BCDChroniclesMovementUpdate(&s, 260, 300), 1, 0);
    expect(BCDChroniclesMovementBegin(&s, 0, 0, 0), 0, 0); assert(!s.active);
    expect(BCDChroniclesMovementBegin(&s, 0, 0, -1), 0, 0); assert(!s.active);
    expect(BCDChroniclesMovementBegin(&s, NAN, 0, 1), 0, 0); assert(!s.active);
    expect(BCDChroniclesMovementBegin(&s, 0, 0, INFINITY), 0, 0); assert(!s.active);
    BCDChroniclesMovementBegin(&s, 0, 0, 1);
    expect(BCDChroniclesMovementUpdate(&s, NAN, 0), 0, 0); assert(!s.active);
    BCDChroniclesMovementBegin(&s, DBL_MAX, 0, 1);
    expect(BCDChroniclesMovementUpdate(&s, -DBL_MAX, 0), 0, 0); assert(!s.active);
    expect(BCDChroniclesMovementBegin(NULL, 0, 0, 1), 0, 0);
    expect(BCDChroniclesMovementUpdate(NULL, 0, 0), 0, 0);
    expect(BCDChroniclesMovementCancel(NULL), 0, 0);
    for (int n=0; n<10000; n++) {
        BCDChroniclesMovementBegin(&s, 0, 0, 1);
        for (int k=0; k<32; k++) {
            double x=randomPoint(), y=randomPoint();
            BCDChroniclesMovementOutput o=BCDChroniclesMovementUpdate(&s,x,y);
            assert(o.horizontal >= -1 && o.horizontal <= 1);
            assert(!o.crouch || (o.horizontal == 0 && y >= 0.85 && fabs(x) <= y*0.80));
            if (y < 0.85) assert(!o.crouch);
        }
        expect(BCDChroniclesMovementCancel(&s),0,0);
        expect(BCDChroniclesMovementUpdate(&s,0,9),0,0);
    }
    puts("PASS: Chronicles semantic sidepad, held-down guards, interruption and 10000 trajectories");
}
