#include "../../app/Madeira/BCDTableTouchPolicy.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
 BCDTableRelativeState s={0};
 BCDTableRelativeBegin(&s,400,200);assert(s.active && !s.dx && !s.dy);
 assert(BCDTableRelativeMove(&s,410,195,2,2));assert(s.dx==20 && s.dy==-10);
 assert(!BCDTableRelativeMove(&s,410,195,2,2));
 /* Lift/re-anchor anywhere: cursor has no absolute or synthetic jump. */
 BCDTableRelativeBegin(&s,30,400);assert(!s.dx && !s.dy);
 assert(BCDTableRelativeMove(&s,35,403,2,-1));assert(s.dx==10 && s.dy==-3);
 BCDTableRelativeBegin(&s,0,0);
 assert(!BCDTableRelativeMove(&s,.2,.2,1,1));
 assert(!BCDTableRelativeMove(&s,.6,.6,1,1));
 assert(BCDTableRelativeMove(&s,1.2,1.2,1,1));assert(s.dx==1 && s.dy==1);
 assert(!BCDTableRelativeMove(&s,NAN,1,1,1) && !s.active);
 assert(!BCDTableRelativeMove(&s,10,10,1,1));
 BCDTableRelativeBegin(&s,0,0);assert(!BCDTableRelativeMove(&s,1,1,INFINITY,1));
 BCDTableRelativeBegin(&s,0,0);assert(BCDTableRelativeMove(&s,1e200,-1e200,8,8));assert(s.dx==32767 && s.dy==-32768);
 puts("PASS: production relative-cursor accumulation, no touchdown warp, re-anchoring, fractional carry, invert/scale and invalid/cancel guards");
 return 0;
}
