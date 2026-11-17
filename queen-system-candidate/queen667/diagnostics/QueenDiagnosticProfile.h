#ifndef QUEEN_DIAGNOSTIC_PROFILE_H
#define QUEEN_DIAGNOSTIC_PROFILE_H
#include <stdlib.h>
#include <string.h>

/* Session setup only, before guest threads start. Explicit per-game/global
 * values win. Restore only defaults owned by this profile; never erase an
 * explicitly supplied setting or a subsequently changed value. */
static const char *const queen_diag_keys[] = {
    "MADEIRA_PROBES", "MADEIRA_LEAN_DIAG", "MADEIRA_QUIET", "MADEIRA_LUM_PROBE", "MADEIRA_FEX_CB_SAMPLE"
};
static const char *queen_diag_owned[5];
static void queen_diag_restore(void) {
    for (unsigned i = 0; i < 5; ++i) {
        const char *v = getenv(queen_diag_keys[i]);
        if (queen_diag_owned[i] && v && !strcmp(v, queen_diag_owned[i]))
            unsetenv(queen_diag_keys[i]);
        queen_diag_owned[i] = NULL;
    }
}
static int queen_diag_apply(void) {
    const char *scope = getenv("BCD_QUEEN_PROFILE");
    const char *choice = getenv("BCD_QUEEN_DIAGNOSTICS");
    if (!scope || strcmp(scope, "1")) return -1;
    const int full = choice && !strcmp(choice, "1");
    const char *values[5] = { full ? "1" : "light", full ? "0" : "1", "1", full ? "1" : "0", full ? "1" : "0" };
    /* MADEIRA_QUIET remains enabled: its legacy separate profiler is not part
     * of the requested burst diagnostics. The normal error log stays intact. */
    for (unsigned i = 0; i < 5; ++i) {
        if (!getenv(queen_diag_keys[i]) && !setenv(queen_diag_keys[i], values[i], 0))
            queen_diag_owned[i] = values[i];
    }
    return full;
}
#endif
