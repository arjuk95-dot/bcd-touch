/* LGPL-2.1-or-later. Shared desktop GL policy; no Wine or Apple dependency. */
#ifndef BCD_GL_POLICY_H
#define BCD_GL_POLICY_H
#include <string.h>
static inline int bcd_gl_enabled(const char *backend, const char *disable) {
    return backend && !strcmp(backend,"zink") && (!disable || !*disable || !strcmp(disable,"0"));
}
static inline int bcd_gl_hardware(const char *renderer) {
    return renderer && strstr(renderer,"zink") && !strstr(renderer,"softpipe") &&
           !strstr(renderer,"llvmpipe") && !strstr(renderer,"SwiftShader") &&
           !strstr(renderer,"Software") && !strstr(renderer,"software");
}
static inline double bcd_gl_cap(int mode, double display, int interval, double override) {
    if (display<30 || display>120) display=60;
    double cap=mode==1?60:mode==3?30:mode==4?40:mode==0?display:0;
    if (override>=10 && override<=120) cap=override;
    if (interval>0 && (!cap || cap>display/interval)) cap=display/interval;
    return cap;
}
#endif
