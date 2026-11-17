#!/usr/bin/env python3
"""Apply after all666 app patches. Exact anchors fail closed; no engine settings."""
from pathlib import Path
import sys
root=Path(sys.argv[1]); app=root/'app/Madeira'; here=Path(__file__).parent
def rep(s,a,b):
    assert s.count(a)==1, (a,s.count(a))
    return s.replace(a,b)
p=app/'Library.swift';s=p.read_text()
a='        if useQueenNav {\n'
s=rep(s,a,a+'            setenv("BCD_QUEEN_PROFILE", "1", 1)\n')
a='            unsetenv("BCD_QUEEN_NATIVE_NAV")'
s=rep(s,a,a+'\n            unsetenv("BCD_QUEEN_PROFILE")')
p.write_text(s)
p=app/'WineProcessBridge.m';s=p.read_text()
s='#include "QueenDiagnosticProfile.h"\n'+s
a='            /* ml1062: environment exports -- the "env.NAME = value" lines of bcd.cfg,'
s=rep(s,a,'            queen_diag_restore(); /* remove only prior profile-owned defaults before re-reading config */\n            unsetenv("BCD_QUEEN_DIAGNOSTICS"); /* config-only mode: never inherit an earlier game\'s opt-in */\n'+a)
a='                {   /* madeira-bcd (round 624, agent R: the Epic GTA V / RDR2 starts 7Z8VKR, TV6H06): env.MADEIRA_STEAM_IDENTITY = none from the'
s=rep(s,a,'''                {
                    int mode = queen_diag_apply();
                    if (mode >= 0) fprintf(stderr, "[queen-profile] %s; probes=%s lean=%s; full bursts require env.BCD_QUEEN_DIAGNOSTICS=1 and a fresh app launch\\n",
                        mode ? "diagnostic" : "production", getenv("MADEIRA_PROBES"), getenv("MADEIRA_LEAN_DIAG"));
                }
'''+a)
a='    unsetenv("BCD_QUEEN_NATIVE_NAV");'
s=rep(s,a,a+'\n    unsetenv("BCD_QUEEN_PROFILE");\n    unsetenv("BCD_QUEEN_DIAGNOSTICS");\n    queen_diag_restore();')
p.write_text(s)
(app/'QueenDiagnosticProfile.h').write_bytes((here/'QueenDiagnosticProfile.h').read_bytes())

print('Applied Queen session-scoped production defaults; explicit settings retained.')
