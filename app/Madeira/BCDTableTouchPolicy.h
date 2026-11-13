// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef BCD_TABLE_TOUCH_POLICY_H
#define BCD_TABLE_TOUCH_POLICY_H
#include <math.h>
// Engine-independent decisions. No click is committed on touchdown: a second
// finger can claim a secondary-click/scroll gesture without playing a card.
typedef struct { double x,y,lastX,lastY,began; int active,drag,inspect,multi,moved; } BCDTableTouchState;
enum { BCD_TABLE_NONE=0, BCD_TABLE_DOWN=1, BCD_TABLE_UP=2, BCD_TABLE_CLICK=4, BCD_TABLE_SECONDARY=8, BCD_TABLE_HOVER=16 };
static inline void BCDTableBegin(BCDTableTouchState *s,double x,double y,double t) { *s=(BCDTableTouchState){x,y,x,y,t,1,0,0,0,0}; }
static inline int BCDTableMove(BCDTableTouchState *s,double x,double y) {
 if(!s->active)return 0;
 if(!isfinite(x)||!isfinite(y)){s->moved=1;return 0;}
 s->lastX=x;s->lastY=y;
 if(hypot(x-s->x,y-s->y)>10)s->moved=1;
 if(s->multi)return 0;
 if(s->moved && !s->drag && !s->inspect){s->drag=1;return BCD_TABLE_DOWN;}
 return BCD_TABLE_HOVER;
}
static inline int BCDTableTick(BCDTableTouchState *s,double t){if(s->active&&!s->multi&&!s->drag&&!s->moved&&t-s->began>=.35)s->inspect=1;return s->inspect?BCD_TABLE_HOVER:0;}
static inline int BCDTableSecond(BCDTableTouchState *s){if(!s->active)return 0;if(s->multi)s->moved=1;s->multi=1;return s->drag?BCD_TABLE_UP:0;}
static inline int BCDTableEnd(BCDTableTouchState *s,int cancelled){int r=0;if(s->active){if(s->drag)r=BCD_TABLE_UP;else if(!cancelled&&!s->moved)r=s->multi?BCD_TABLE_SECONDARY:(!s->inspect?BCD_TABLE_CLICK:0);}s->active=0;return r;}
static inline void BCDTableSecondMove(BCDTableTouchState *s,double sx,double sy,double x,double y) {
 if(!isfinite(x)||!isfinite(y)||hypot(x-sx,y-sy)>10)s->moved=1;
}
static inline int BCDTableEndAt(BCDTableTouchState *s,double x,double y,double now,int cancelled) {
 if(!isfinite(x)||!isfinite(y)||!isfinite(now)||now<s->began)cancelled=1;
 else { (void)BCDTableMove(s,x,y); (void)BCDTableTick(s,now); if(s->multi&&now-s->began>.35)cancelled=1; }
 return BCDTableEnd(s,cancelled);
}
#endif
