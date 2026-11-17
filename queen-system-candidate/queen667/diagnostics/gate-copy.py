#!/usr/bin/env python3
from pathlib import Path
import sys
def rep(s,a,b):
 assert s.count(a)==1
 return s.replace(a,b)
# This is our own666 instrumentation header, not a modification to FEX's
# translator algorithms or a replacement memcpy implementation.
p=Path(sys.argv[1])/'QueenCopySampling.h'
s=p.read_text();a='static void InstallQueenCopySampling() {\n'
s=rep(s,a,a+'''  const char* diagnostics=getenv("BCD_QUEEN_DIAGNOSTICS");
  if(!diagnostics || strcmp(diagnostics,"1")) {
    LogMan::Msg::EFmt("[queen-copy] disabled in production mode");return;
  }
''')
p.write_text(s)
print('Applied Queen session-scoped production defaults and opt-in copy histogram; explicit settings retained.')
