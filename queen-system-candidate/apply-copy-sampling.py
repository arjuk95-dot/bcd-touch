#!/usr/bin/env python3
"""Future Queen candidate only. Apply after guest leaf route/install integration.
No memcpy/memset redirection or thresholds. Does NOT modify shared Wine structs.
"""
from pathlib import Path
import sys
root=Path(sys.argv[1]); here=Path(__file__).parent
p=root/'Source/Windows/ARM64EC/Module.S';s=p.read_text()
anchor='// Read by RetToEntryThunk below; ARM64EC/Module.cpp sets it at process init.'
assert s.count(anchor)==1
s=s.replace(anchor,(here/'sample.inc.S').read_text()+'\n'+anchor)
start=s.index('ExitFunctionECJit:');end=s.index('.global ExitFunctionEC\n',start)
body=s[start:end];anchor='  str x9, [x17, x23, lsl #3]'
assert body.count(anchor)==1
body=body.replace(anchor,anchor+'\n  QUEEN_COPY_SAMPLE')
s=s[:start]+body+s[end:]
# Existing uint32_t size had an erroneous 64-bit scaled load. New globals
# exposed its natural 4-byte alignment; use exact type width, not padding.
size_load='  ldr x17, [x17, #:lo12:NtDllRedirectionLUTSize]'
assert s.count(size_load)==1
s=s.replace(size_load,'  ldr w17, [x17, #:lo12:NtDllRedirectionLUTSize]')
p.write_text(s)

p=root/'FEXCore/Source/Interface/Core/Core.cpp';s=p.read_text()
declaration='''#if defined(FEX_IOS_HOST) && defined(ARCHITECTURE_arm64ec)
extern "C" void QueenCopyReport();
#endif
'''
anchor='  /* iOS-Madeira ml316: report ExitToX64 FFS bypasses'
assert s.count(anchor)==1
s=s.replace(anchor,'''#if defined(FEX_IOS_HOST) && defined(ARCHITECTURE_arm64ec)
  QueenCopyReport();
#endif
'''+anchor)
p.write_text(declaration+s)

# Locate integrated installer, rather than assume a repository-relative bundle.
installers=list(root.rglob('QueenGuestLeafInstall.h'))
assert len(installers)==1, 'Expected one integrated guest leaf installer'
p=installers[0];s=p.read_text()
anchor='  for(size_t i=0;i<4;++i)FEXCore::Core::QueenGuestLeafRegister(targets[i],guests[i]);'
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'\n  InstallQueenCopySampling();')
s=s.replace('#pragma once','#pragma once\n#include "QueenCopySampling.h"',1)
p.write_text(s)
(p.parent/'QueenCopySampling.h').write_bytes((here/'QueenCopySampling.h').read_bytes())
print('Wired sampled-only ASM writer + FEX reporter + validated startup activation; no CRT fastpath.')
