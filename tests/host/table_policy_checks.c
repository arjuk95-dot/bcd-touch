#include "../../app/Madeira/BCDTableTouchPolicy.h"
#include <assert.h>
int main(void){BCDTableTouchState s;
 BCDTableBegin(&s,0,0,0);assert(BCDTableEnd(&s,0)==BCD_TABLE_CLICK);
 BCDTableBegin(&s,0,0,0);BCDTableTick(&s,.4);assert(BCDTableEnd(&s,0)==0);
 BCDTableBegin(&s,0,0,0);assert(BCDTableMove(&s,20,0)==BCD_TABLE_DOWN);assert(BCDTableEnd(&s,1)==BCD_TABLE_UP);
 BCDTableBegin(&s,0,0,0);assert(BCDTableSecond(&s)==0);assert(BCDTableEnd(&s,0)==BCD_TABLE_SECONDARY);
 BCDTableBegin(&s,0,0,0);BCDTableSecond(&s);BCDTableMove(&s,0,30);assert(BCDTableEnd(&s,0)==0);
 BCDTableBegin(&s,0,0,0);assert(BCDTableEnd(&s,1)==0);
 // Final displacement without a delivered move never becomes a click.
 BCDTableBegin(&s,0,0,0);assert(!(BCDTableEndAt(&s,30,0,.1,0)&BCD_TABLE_CLICK));
 BCDTableBegin(&s,0,0,0);BCDTableSecond(&s);BCDTableSecondMove(&s,0,0,25,0);assert(BCDTableEndAt(&s,0,0,.1,0)==0);
 BCDTableBegin(&s,0,0,0);BCDTableSecond(&s);BCDTableSecondMove(&s,0,0,25,0);BCDTableSecondMove(&s,0,0,0,0);assert(BCDTableEndAt(&s,0,0,.1,0)==0);
 BCDTableBegin(&s,0,0,0);BCDTableSecond(&s);BCDTableSecond(&s);assert(BCDTableEndAt(&s,0,0,.1,0)==0);
 BCDTableBegin(&s,0,0,0);BCDTableSecond(&s);assert(BCDTableEndAt(&s,0,0,.4,0)==0);
 BCDTableBegin(&s,0,0,0);assert(BCDTableEndAt(&s,NAN,0,.1,0)==0);
 BCDTableBegin(&s,0,0,1);assert(BCDTableEndAt(&s,0,0,0,0)==0);
 BCDTableBegin(&s,0,0,0);BCDTableSecond(&s);assert(BCDTableEndAt(&s,0,0,.2,0)==BCD_TABLE_SECONDARY);
 BCDTableBegin(&s,0,0,0);BCDTableMove(&s,NAN,0);assert(!(BCDTableEndAt(&s,0,0,.2,0)&BCD_TABLE_CLICK));
 BCDTableBegin(&s,0,0,0);assert(BCDTableEndAt(&s,0,0,.6,0)==0);
 return 0;}
