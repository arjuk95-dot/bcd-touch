#include <assert.h>
#include <stdio.h>
#include "../../build/win32u-unix/gl_policy.h"
int main(void) {
 assert(!bcd_gl_enabled(NULL,NULL));assert(!bcd_gl_enabled("gles",NULL));
 assert(bcd_gl_enabled("zink",NULL));assert(bcd_gl_enabled("zink","0"));
 assert(!bcd_gl_enabled("zink","1"));assert(!bcd_gl_enabled("off","0"));
 assert(!bcd_gl_hardware(NULL));assert(!bcd_gl_hardware("llvmpipe"));
 assert(!bcd_gl_hardware("zink (llvmpipe)"));assert(!bcd_gl_hardware("zink (SwiftShader)"));
 assert(!bcd_gl_hardware("zink (Software Vulkan)"));assert(bcd_gl_hardware("zink (Apple A18 Pro)"));
 assert(bcd_gl_cap(1,120,0,0)==60);assert(bcd_gl_cap(3,120,1,0)==30);
 assert(bcd_gl_cap(4,120,1,0)==40);assert(bcd_gl_cap(2,120,0,0)==0);
 assert(bcd_gl_cap(0,120,0,0)==120);assert(bcd_gl_cap(2,120,2,0)==60);
 assert(bcd_gl_cap(2,120,0,24)==24);assert(bcd_gl_cap(1,0,0,0)==60);
 puts("PASS: backend disable, software rejection and 24/30/40/60/120 pacing policy");
}
