#!/usr/bin/env python3
"""Generate, but NEVER execute, a targeted ARM64EC d3d11 build recipe."""
import hashlib
from pathlib import Path
here=Path(__file__).resolve().parent
original=here.parent/'baseline-source/tools/build-d3d11-dll.sh'
raw=original.read_bytes()
assert hashlib.sha256(raw).hexdigest()=='2bfc166c46f11a7cf6008a173e51e32ebff3a4dd4450cd1c92cc55aaa979cf6a'
s=raw.decode().replace('\r\n','\n')
def between(a,b):return s[s.index(a):s.index(b)]
setup=between('set -eu\n','# madeira-bcd: since the 2026-10-15')
setup=setup.replace('OUT="${D3D11_OUT:-$R/build/dxmt-d3d11}"','OUT="${D3D11_OUT:-$R/build-out/queen-render}"')
guards='''
: "${QUEEN_RENDER_PATCH:?absolute path to reviewed patch required}"
test "$(git -C "$D" rev-parse --short=7 HEAD)" = bbbb3aa || fail "wrong DXMT pin"
test -z "$(git -C "$D" status --porcelain)" || fail "DXMT must be pristine"
test ! -e "$OUT" || fail "use a fresh isolated D3D11_OUT"
mkdir -p "$OUT/obj" "$OUT/plain/obj" "$OUT/gen" "$OUT/tree/src"
shasum -a256 "$SHIP/d3d11.dll" > "$OUT/stock-before.sha256"
REV="$(git -C "$D" rev-parse --short HEAD)"
'''
imports=between('exports() {','# The d3d11 and d3d10 sources with SwapDeviceContextState')
copy='''
# No inherited BCD patch scripts: pinned source already contains its own fixes.
cp -R "$D/src/d3d11" "$D/src/d3d10" "$D/src/dxmt" "$OUT/tree/src/"
git -C "$OUT/tree" init -q
'''
compiler=between('# DXMT\'s meson.build: compiler_args','echo "compiling $(wc -l')
# Baseline objects only. Candidate shares every unchanged baseline object.
compiler=compiler.replace('    o="$OUT/obj/dxmt_$s.o"; job "$OUT/tree" "$OUT/tree/src/dxmt/$s.cpp" "$o" dxmt; DXMT_OBJ+=("$o")\n','')
compiler=compiler.replace('    o="$OUT/obj/$(obj_name "$s").o"; job "$OUT/tree" "$OUT/tree/src/$s.cpp" "$o" d3d11; PATCHED_OBJ+=("$o")\n','')
compile_and_link=between('echo "compiling $(wc -l','link_dll "$OUT/plain/d3d11.dll"')
compile_and_link=compile_and_link.replace('"$AR" csrDT "$OUT/libdxmt.a" "${DXMT_OBJ[@]}"\n','')
finish=(here/'targeted-tail.sh').read_text()
output='#!/bin/bash\n# LOCAL REVIEW RECIPE. No workflow or automatic trigger.\n'+setup+guards+imports+copy+compiler+compile_and_link+finish
(here/'build-queen-render.sh').write_text(output,newline='\n')
print(here/'build-queen-render.sh')
