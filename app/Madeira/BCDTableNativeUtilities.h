#ifndef BCD_TABLE_NATIVE_UTILITIES_H
#define BCD_TABLE_NATIVE_UTILITIES_H
#include <stdint.h>
#include <string.h>
/* Pure utility lookup; never owns touches or changes a saved pack.
 * Return value is an XInput button MASK, not a button ordinal.
 * Zero means unavailable, never a keyboard/pointer fallback. */
typedef enum { BCDTableSTS2, BCDTableSkald } BCDTableNativeGame;
typedef enum { BCDTableSelect, BCDTableCancel, BCDTableMap,
    BCDTableInventory, BCDTableJournal, BCDTableHoverInspect,
    BCDTableConfirmEndTurn } BCDTableNativeUtility;
static inline uint16_t BCDTableNativeButton(BCDTableNativeGame game,
    BCDTableNativeUtility utility, const char *codeSHA, const char *inputSHA,
    int contextAllowsInventory) {
    if (!codeSHA || !inputSHA) return 0;
    /* Exact shipped Godot project InputEventJoypadButton records + native IL. */
    if (game == BCDTableSTS2) {
        if (strcmp(codeSHA,"0861bfa1df347538d932f22d580e75420f08082792eb914e53b4882764acdbe9") ||
            strcmp(inputSHA,"88bc2e4f6a2627204b20a714cb8746a269c009e48255dcfc7a0eaef9503d2227")) return 0;
        return utility == BCDTableCancel ? 0x2000 : utility == BCDTableMap ? 0x0020 : 0;
    }
    if (game != BCDTableSkald) return 0;
    if (strcmp(codeSHA,"a9929c9e7e7f06829692ae7c23df2c147d64ea050bdf18649adbd44e1fbcd075") ||
        strcmp(inputSHA,"faca117d2bcfacc1ea980de701253fff20b8c7fb93e01b7033a1f3820697f6a8")) return 0;
    switch (utility) {
        case BCDTableSelect: return 0x1000; /* joystick0 = A: Interact/Enter */
        case BCDTableCancel: return 0x2000; /* joystick1 = B: Escape */
        case BCDTableInventory: return contextAllowsInventory ? 0x4000 : 0;
        case BCDTableJournal: return 0x0010; /* joystick7 = Menu */
        default: return 0;
    }
}
#endif
