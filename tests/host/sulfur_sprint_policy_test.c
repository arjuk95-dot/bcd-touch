#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "BCDSulfurSprintPolicy.h"
static void begin(BCDSulfurSprintState*s){assert(!BCDSulfurSprintBegin(s,0,1));}
int main(void){BCDSulfurSprintState s={0};
 assert(!BCDSulfurSprintUpdate(&s,0,-2,1,1));begin(&s);
 assert(!BCDSulfurSprintUpdate(&s,0,-1.2,0,1));
 assert(!BCDSulfurSprintUpdate(&s,0,-1.2,.119,1));
 assert(BCDSulfurSprintUpdate(&s,0,-1.2,.121,1)==1);
 assert(!BCDSulfurSprintUpdate(&s,0,-1.2,.5,1));
 assert(!BCDSulfurSprintUpdate(&s,0,0,1,1));
 assert(!BCDSulfurSprintUpdate(&s,0,-1.2,2,1));
 assert(!BCDSulfurSprintUpdate(&s,0,-1.2,3,1));
 assert(!BCDSulfurSprintCancel(&s));assert(!BCDSulfurSprintUpdate(&s,0,-2,4,1));
 begin(&s);BCDSulfurSprintUpdate(&s,0,-1.15,0,1);assert(!BCDSulfurSprintUpdate(&s,0,-1.15,1,1));
 begin(&s);BCDSulfurSprintUpdate(&s,.6,-1.2,0,1);assert(!BCDSulfurSprintUpdate(&s,.6,-1.2,1,1));
 begin(&s);BCDSulfurSprintUpdate(&s,0,-2,0,1);BCDSulfurSprintUpdate(&s,0,0,.1,1);
 assert(!BCDSulfurSprintUpdate(&s,0,-2,.2,1));assert(BCDSulfurSprintUpdate(&s,0,-2,.321,1)==1);
 begin(&s);BCDSulfurSprintUpdate(&s,0,-2,0,1);assert(!BCDSulfurSprintUpdate(&s,0,-2,.2,0));assert(!BCDSulfurSprintUpdate(&s,0,-2,1,1));
 begin(&s);BCDSulfurSprintUpdate(&s,0,-2,.1,1);assert(!BCDSulfurSprintUpdate(&s,0,-2,0,1));assert(!s.active);
 const double bad[]={NAN,INFINITY,-INFINITY};for(int i=0;i<3;i++){
 begin(&s);assert(!BCDSulfurSprintUpdate(&s,bad[i],-2,.2,1)&&!s.active);
 begin(&s);assert(!BCDSulfurSprintUpdate(&s,0,bad[i],.2,1)&&!s.active);
 begin(&s);assert(!BCDSulfurSprintUpdate(&s,0,-2,bad[i],1)&&!s.active);
 assert(!BCDSulfurSprintBegin(&s,bad[i],1)&&!s.active);}
 assert(!BCDSulfurSprintBegin(&s,0,0));assert(!BCDSulfurSprintUpdate(&s,0,-2,1,1));
 uint32_t r=42;for(int p=0;p<4000;p++){begin(&s);int count=0;
 for(int i=0;i<100;i++){r=r*1664525u+1013904223u;double x=((int)(r%401)-200)/100.;r=r*1664525u+1013904223u;double y=((int)(r%401)-200)/100.;int pulse=BCDSulfurSprintUpdate(&s,x,y,i*.02,1);count+=pulse;assert(count<=1);if(pulse)assert(-y>1.15&&fabs(x)<=-y*.45);}
 assert(!BCDSulfurSprintCancel(&s));}
 puts("PASS: controller sprint one-shot, dwell, cancellation, invalid input and 4000 trajectories");}
