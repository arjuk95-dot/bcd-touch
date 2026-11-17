#include <assert.h>
#include <float.h>
#include <stdio.h>
#include "../../app/Madeira/BCDInscryptionSwipePolicy.h"
static int stroke(double x, double y, double t) {
    BCDInscryptionSwipeState s = {0};
    assert(BCDInscryptionSwipeBegin(&s, 0, 0, 0) == 0);
    return BCDInscryptionSwipeEnd(&s, x, y, t, 0);
}
int main(void) {
    assert(stroke(0,0,2) == 1); /* hold remains caller-owned */
    assert(stroke(8,0,.1) == 1);
    assert(stroke(8.001,0,.1) == 0);
    assert(stroke(23.999,0,.1) == 0);
    assert(stroke(24,0,.65) == 3);
    assert(stroke(-24,0,.65) == 2);
    assert(stroke(0,-24,.65) == 4);
    assert(stroke(0,24,.65) == 5);
    assert(stroke(24,0,.650001) == 0);
    assert(stroke(27,20,.2) == 3);
    assert(stroke(26.999,20,.2) == 0);
    assert(stroke(24,24,.2) == 0);
    assert(stroke(0,0,-.1) == 0);
    assert(stroke(NAN,0,.2) == 0);
    assert(stroke(24,INFINITY,.2) == 0);
    assert(stroke(24,0,NAN) == 0);
    BCDInscryptionSwipeState s = {0};
    assert(BCDInscryptionSwipeEnd(&s,24,0,.1,0) == 0);
    for (int dir=2; dir<=5; ++dir) {
        double x = dir==2 ? -1 : dir==3 ? 1 : 0;
        double y = dir==4 ? -1 : dir==5 ? 1 : 0;
        BCDInscryptionSwipeBegin(&s,100,100,10);
        for (int i=1;i<=32;++i)
            assert(BCDInscryptionSwipeMove(&s,100+x*i,100+y*i) == 0);
        assert(BCDInscryptionSwipeEnd(&s,100+x*32,100+y*32,10.5,0)==dir);
        assert(BCDInscryptionSwipeEnd(&s,100+x*32,100+y*32,10.5,0)==0);
    }
    BCDInscryptionSwipeBegin(&s,0,0,0);
    BCDInscryptionSwipeMove(&s,30,0);
    assert(BCDInscryptionSwipeEnd(&s,0,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,0,0,0);
    BCDInscryptionSwipeMove(&s,40,0);
    assert(BCDInscryptionSwipeEnd(&s,30,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,0,0,0);
    BCDInscryptionSwipeMove(&s,20,0);
    BCDInscryptionSwipeMove(&s,0,30);
    assert(BCDInscryptionSwipeEnd(&s,40,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,0,0,0);
    BCDInscryptionSwipeMove(&s,12,12);
    assert(BCDInscryptionSwipeEnd(&s,40,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,0,0,0);
    BCDInscryptionSwipeMove(&s,NAN,0);
    assert(BCDInscryptionSwipeEnd(&s,40,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,0,0,0);
    assert(BCDInscryptionSwipeEnd(&s,24,0,.2,1)==0);
    BCDInscryptionSwipeBegin(&s,0,0,0);
    assert(BCDInscryptionSwipeCancel(&s)==0);
    assert(BCDInscryptionSwipeEnd(&s,24,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,INFINITY,0,0);
    assert(BCDInscryptionSwipeEnd(&s,24,0,.2,0)==0);
    BCDInscryptionSwipeBegin(&s,DBL_MAX,0,0);
    assert(BCDInscryptionSwipeEnd(&s,-DBL_MAX,0,.2,0)==0);
    assert(BCDInscryptionSwipeBegin(NULL,0,0,0)==0);
    assert(BCDInscryptionSwipeMove(NULL,0,0)==0);
    assert(BCDInscryptionSwipeEnd(NULL,0,0,0,0)==0);
    puts("Inscryption swipe policy checks passed");
    return 0;
}
