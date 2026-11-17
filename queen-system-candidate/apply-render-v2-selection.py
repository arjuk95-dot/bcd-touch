#!/usr/bin/env python3
"""Apply after 665 apply-queen-render-app.py; no build or deployment by itself."""
import sys
from pathlib import Path
app=Path(sys.argv[1])/'app/Madeira'
def replace(s,a,b):
 assert s.count(a)==1, a
 return s.replace(a,b)
p=app/'Library.swift';s=p.read_text()
a='            if getenv("BCD_QUEEN_RENDER_BATCH") == nil { setenv("BCD_QUEEN_RENDER_BATCH", "0", 1) }'
s=replace(s,a,a+'\n            if getenv("BCD_QUEEN_RENDER_V2") == nil { setenv("BCD_QUEEN_RENDER_V2", "1", 1) }\n            if getenv("BCD_QUEEN_GS_PAYLOAD") == nil { setenv("BCD_QUEEN_GS_PAYLOAD", "1", 1) }\n            if getenv("BCD_QUEEN_NATIVE_GRAPHICS") == nil { setenv("BCD_QUEEN_NATIVE_GRAPHICS", "1", 1) }')
s=replace(s,'            unsetenv("BCD_QUEEN_RENDER_BATCH")','            unsetenv("BCD_QUEEN_RENDER_BATCH")\n            unsetenv("BCD_QUEEN_RENDER_V2")\n            unsetenv("BCD_QUEEN_GS_PAYLOAD")\n            unsetenv("BCD_QUEEN_NATIVE_GRAPHICS")')
p.write_text(s)
p=app/'WineProcessBridge.m';s=p.read_text()
s=replace(s,'                const char *batch = getenv("BCD_QUEEN_RENDER_BATCH");\n                if (use_arm64ec && batch && !strcmp(batch, "1")) {','                const char *renderer = getenv("BCD_QUEEN_RENDER_V2");\n                if (use_arm64ec && renderer && !strcmp(renderer, "1")) {')
s=replace(s,'stringByAppendingPathComponent:@"d3d11-queen.dll"','stringByAppendingPathComponent:@"d3d11-queen-v2.dll"')
s=replace(s,'                        unsetenv("BCD_QUEEN_RENDER_BATCH");','                        unsetenv("BCD_QUEEN_RENDER_V2");\n                        unsetenv("BCD_QUEEN_GS_PAYLOAD");')
s=s.replace('[queen-submit] renderer link failed','[queen-render-v2] renderer link failed').replace('[queen-submit] Queen renderer selection attempted; activation is confirmed by PE counters','[queen-render-v2] renderer selection attempted; verify loaded PE identity').replace('[queen-submit] candidate absent; existing renderer unchanged','[queen-render-v2] candidate absent; existing renderer unchanged')
s=replace(s,'    unsetenv("BCD_QUEEN_RENDER_BATCH");','    unsetenv("BCD_QUEEN_RENDER_BATCH");\n    unsetenv("BCD_QUEEN_RENDER_V2");\n    unsetenv("BCD_QUEEN_GS_PAYLOAD");\n    unsetenv("BCD_QUEEN_NATIVE_GRAPHICS");')
p.write_text(s)
print('Renderer V2 selected independently; batching remains default0; paired GS payload enabled within Queen scope')
