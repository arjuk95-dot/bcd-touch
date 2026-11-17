#!/usr/bin/env python3
"""Apply after native-nav-and-badge app patch. No layout or game-data edits."""
import sys
from pathlib import Path
root=Path(sys.argv[1]); app=root/'app/Madeira'
p=app/'Library.swift';s=p.read_text()
a='        if useQueenNav { setenv("BCD_QUEEN_NATIVE_NAV", "1", 1) }\n        else { unsetenv("BCD_QUEEN_NATIVE_NAV") }'
b='''        // Explicit per-game value 0 permits independent A/B without another IPA.
        if useQueenNav {
            if getenv("BCD_QUEEN_NATIVE_NAV") == nil { setenv("BCD_QUEEN_NATIVE_NAV", "1", 1) }
            if getenv("BCD_QUEEN_RENDER_BATCH") == nil { setenv("BCD_QUEEN_RENDER_BATCH", "0", 1) }
            if getenv("BCD_QUEEN_NATIVE_RHI") == nil { setenv("BCD_QUEEN_NATIVE_RHI", "1", 1) }
        } else {
            unsetenv("BCD_QUEEN_NATIVE_NAV")
            unsetenv("BCD_QUEEN_RENDER_BATCH")
            unsetenv("BCD_QUEEN_NATIVE_RHI")
        }'''
assert s.count(a)==1;s=s.replace(a,b);p.write_text(s)
p=app/'WineProcessBridge.m';s=p.read_text()
a='                if (use_arm64ec && queenNav && !strcmp(queenNav, "1")) {'
b='''                const char *queenRhi = getenv("BCD_QUEEN_NATIVE_RHI");
                if (use_arm64ec && ((queenNav && !strcmp(queenNav, "1")) || (queenRhi && !strcmp(queenRhi, "1")))) {'''
assert s.count(a)==1;s=s.replace(a,b)
a='            /* madeira-bcd (2026-10-23): env.MADEIRA_D3D9_X64 = dxmt'
b='''            /* Per-session Queen renderer only. Normal DLL farms are restored on
             * every launch; no stock bundle DLL, game file or save is replaced. */
            {
                const char *batch = getenv("BCD_QUEEN_RENDER_BATCH");
                if (use_arm64ec && batch && !strcmp(batch, "1")) {
                    NSString *candidate = [[bundlePath stringByAppendingPathComponent:@"arm64ec-windows"]
                                           stringByAppendingPathComponent:@"d3d11-queen.dll"];
                    if ([fm fileExistsAtPath:candidate]) {
                        for (NSString *dir in @[ sys32Dir, [prefix stringByAppendingPathComponent:@"drive_c/windows/sysx64"] ]) {
                            NSString *dst = [dir stringByAppendingPathComponent:@"d3d11.dll"];
                            NSString *temp = [dst stringByAppendingString:@".queen-new"];
                            unlink(temp.fileSystemRepresentation);
                            if (symlink(candidate.fileSystemRepresentation, temp.fileSystemRepresentation) != 0 ||
                                rename(temp.fileSystemRepresentation, dst.fileSystemRepresentation) != 0) {
                                dprintf(STDERR_FILENO, "[queen-submit] renderer link failed; existing slot preserved (errno=%d)\\n", errno);
                                unlink(temp.fileSystemRepresentation);
                            }
                        }
                        dprintf(STDERR_FILENO, "[queen-submit] Queen renderer selection attempted; activation is confirmed by PE counters\\n");
                    } else {
                        unsetenv("BCD_QUEEN_RENDER_BATCH");
                        dprintf(STDERR_FILENO, "[queen-submit] candidate absent; existing renderer unchanged\\n");
                    }
                }
            }

'''+a
assert s.count(a)==1;s=s.replace(a,b)
a='    unsetenv("BCD_QUEEN_NATIVE_NAV");'
assert s.count(a)==1;s=s.replace(a,a+'\n    unsetenv("BCD_QUEEN_RENDER_BATCH");\n    unsetenv("BCD_QUEEN_NATIVE_RHI");')
p.write_text(s)
print('Queen-only renderer selection wired after existing source-DLL override; independent per-game opt-out retained')

