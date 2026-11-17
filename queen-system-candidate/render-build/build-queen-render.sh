#!/bin/bash
# LOCAL REVIEW RECIPE. No workflow or automatic trigger.
set -eu
R="$(pwd)"
MINGW="${MINGW:-$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin}"
D="$R/dxmt"
U="$D/src/util"
X="$D/src/dxmt"
G="$D/src/dxgi"
P="$D/libs/DXBCParser"
SHIP="$R/app/Madeira/arm64ec-windows"
OUT="${D3D11_OUT:-$R/build-out/queen-render}"
DEST="$SHIP/d3d11-src.dll"
CXX="$MINGW/arm64ec-w64-mingw32-clang++"
CC="$MINGW/arm64ec-w64-mingw32-clang"
WINDRES="$MINGW/arm64ec-w64-mingw32-windres"
AR="$MINGW/llvm-ar"
READOBJ="$MINGW/llvm-readobj"
NM="$MINGW/llvm-nm"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
MARK="madeira-bcd: SwapDeviceContextState in use"

fail() {
    echo "::warning::d3d11-src.dll NOT built ($*). Upstream's d3d11.dll ships alone; env.MADEIRA_D3D11_SRC = 1 has no effect in this build."
    exit 1
}

[ -x "$CXX" ] || fail "no arm64ec clang++ at $CXX: llvm-mingw missing"
[ -f "$D/src/d3d11/d3d11_context_impl.cpp" ] && [ -f "$D/src/d3d10/d3d10_device.cpp" ] || fail "dxmt/src/d3d11 is not checked out"
for f in d3d11.dll dxgi.dll winemetal.dll; do
    [ -f "$SHIP/$f" ] || fail "the committed arm64ec $f is missing"
done


: "${QUEEN_RENDER_PATCH:?absolute path to reviewed patch required}"
test "$(git -C "$D" rev-parse --short=7 HEAD)" = bbbb3aa || fail "wrong DXMT pin"
test -z "$(git -C "$D" status --porcelain)" || fail "DXMT must be pristine"
test ! -e "$OUT" || fail "use a fresh isolated D3D11_OUT"
mkdir -p "$OUT/obj" "$OUT/plain/obj" "$OUT/gen" "$OUT/tree/src"
shasum -a256 "$SHIP/d3d11.dll" > "$OUT/stock-before.sha256"
REV="$(git -C "$D" rev-parse --short HEAD)"
exports() { "$READOBJ" --coff-exports "$1" | awk '$1 == "Name:" && $2 != "" { print $2 }' | sort -u; }

# winemetal.dll's import library, from the binary that ships beside it.
{ echo "LIBRARY winemetal.dll"; echo "EXPORTS"; exports "$SHIP/winemetal.dll"; } > "$OUT/winemetal.def"
"$MINGW/llvm-dlltool" -m arm64ec -d "$OUT/winemetal.def" -l "$OUT/libwinemetal.a" || fail "llvm-dlltool failed for winemetal.dll"
# DXGI.DLL's, from dxgi.def as meson's (the import table names DXGI.DLL), and
# every name in it must be exported by the dxgi.dll that ships.
exports "$SHIP/dxgi.dll" > "$OUT/dxgi.exports"
for n in $(awk 'NR > 2 && $1 != "" { print $1 }' "$G/dxgi.def"); do
    grep -qx "$n" "$OUT/dxgi.exports" || fail "the committed dxgi.dll does not export $n (dxgi.def)"
done
"$MINGW/llvm-dlltool" -m arm64ec -d "$G/dxgi.def" -l "$OUT/libdxgi.a" || fail "llvm-dlltool failed for dxgi.def"

# version.h (vcs_tag).
UPVER="$(LC_ALL=C strings -a "$SHIP/d3d11.dll" | grep -m 1 -E '^v[0-9][0-9.]*-[0-9]+-g[0-9a-f]+$' || true)"
case "$UPVER" in
    *-g"$REV") VER="$UPVER" ;;
    *) VER="$(git -C "$D" describe --always 2>/dev/null || echo unknown)" ;;
esac
sed "s/@VCS_TAG@/$VER/" "$D/version.h.in" > "$OUT/gen/version.h"

# dxmt_command.h: upstream's embedded metallib, out of the committed d3d11.dll.
"$NM" --defined-only "$SHIP/d3d11.dll" > "$OUT/nm.ship" || fail "llvm-nm cannot read the committed d3d11.dll"
python3 - "$SHIP/d3d11.dll" "$OUT/nm.ship" "$OUT/gen/dxmt_command.h" "$OUT/gen/dxmt_command.metallib" <<'PY' || fail "could not take dxmt_command (the embedded metallib) out of the committed d3d11.dll"
import struct, sys
dll, nm, header, blob = sys.argv[1:5]
pe = open(dll, "rb").read()
o = struct.unpack_from("<I", pe, 0x3C)[0]
nsec, optsz = struct.unpack_from("<H", pe, o + 6)[0], struct.unpack_from("<H", pe, o + 20)[0]
base = struct.unpack_from("<Q", pe, o + 24 + 24)[0]
secs = [struct.unpack_from("<IIII", pe, o + 24 + optsz + 40 * i + 8) for i in range(nsec)]
def at(va, n):
    rva = va - base
    for vsize, vaddr, rawsize, rawptr in secs:
        if vaddr <= rva and rva + n <= vaddr + min(vsize, rawsize):
            return pe[rawptr + rva - vaddr: rawptr + rva - vaddr + n]
    sys.exit("address 0x%x (+%d) is not in the file" % (va, n))
sym = {}
for line in open(nm):
    f = line.split()
    if len(f) == 3:
        sym[f[2]] = int(f[0], 16)
if "dxmt_command" not in sym or "dxmt_command_len" not in sym:
    sys.exit("no dxmt_command / dxmt_command_len symbol")
n = struct.unpack("<I", at(sym["dxmt_command_len"], 4))[0]
if not 1000 < n < (8 << 20):
    sys.exit("implausible dxmt_command_len %d" % n)
data = at(sym["dxmt_command"], n)
if data[:4] != b"MTLB":
    sys.exit("dxmt_command does not start with a metallib header")
open(blob, "wb").write(data)
with open(header, "w") as h:
    h.write("unsigned char dxmt_command[] = {\n")
    for i in range(0, n, 12):
        h.write("  " + ", ".join("0x%02x" % b for b in data[i:i + 12]) + ("," if i + 12 < n else "") + "\n")
    h.write("};\nunsigned int dxmt_command_len = %d;\n" % n)
print("dxmt_command: %d bytes from the committed d3d11.dll" % n)
PY
METAL_NOTE="metallib taken from upstream's binary"
if command -v xcrun > /dev/null 2>&1 && xcrun -sdk macosx metal --version > /dev/null 2>&1; then
    if (cd "$OUT/gen" && xcrun -sdk macosx metal -o dxmt_command.air -c "$X/dxmt_command.metal" \
            && xcrun -sdk macosx metallib -o dxmt_command.xcrun.metallib dxmt_command.air) > "$OUT/gen/metal.log" 2>&1; then
        if cmp -s "$OUT/gen/dxmt_command.xcrun.metallib" "$OUT/gen/dxmt_command.metallib"; then
            METAL_NOTE="$METAL_NOTE, identical to this Xcode's build of dxmt_command.metal"
        else
            METAL_NOTE="$METAL_NOTE; this Xcode's build of dxmt_command.metal differs ($(wc -c < "$OUT/gen/dxmt_command.xcrun.metallib" | tr -d ' ') vs $(wc -c < "$OUT/gen/dxmt_command.metallib" | tr -d ' ') bytes, compiler version)"
        fi
    fi
fi


# No inherited BCD patch scripts: pinned source already contains its own fixes.
cp -R "$D/src/d3d11" "$D/src/d3d10" "$D/src/dxmt" "$D/src/airconv" "$OUT/tree/src/"
git -C "$OUT/tree" init -q
# DXMT's meson.build: compiler_args, the project defines, buildtype=release
# (-O3, b_ndebug=if-release -> NDEBUG), C++20. -fmacro-prefix-map maps the
# source root away as meson's '-fmacro-prefix-map=../=' does from its build
# directory; it is added per file with the root that file was taken from.
COMMON=(
    -O3 -DNDEBUG
    -Wimplicit-fallthrough -Wno-missing-field-initializers -Wno-unused-parameter
    -Wno-cast-function-type -Wno-unused-private-field -Wno-microsoft-exception-spec
    -Wno-extern-c-compat -Wno-unused-const-variable -Wno-missing-braces -fblocks
    -DNOMINMAX -D_WIN32_WINNT=0xa00 -DDXMT_IOS=1
)
CXXFLAGS=(-std=c++20 "${COMMON[@]}" -DDXMT_PAGE_SIZE=4096)
CFLAGS=("${COMMON[@]}")
# Include paths per meson target (its own directory first, then the
# dependencies' include_directories, then the generated headers). The dxmt
# directory is the one of the root a file is compiled from: the submodule's
# ($X) for the unpatched build, the copy's for d3d11-src.dll.
INC_BASE=(-I"$D/include" -I"$D/libs")
INC_UTIL=(-I"$U" "${INC_BASE[@]}")
INC_PARSER=(-I"$P" "${INC_BASE[@]}")
INC_DXMT=(-I"$U" -I"$D/src/airconv" -I"$D/src/winemetal" "${INC_BASE[@]}" -I"$OUT/gen")

# Compile jobs: one line per object, "<root>\t<source>\t<object>\t<flag set>",
# run JOBS at a time (plain bash 3 job control: N workers over slices).
: > "$OUT/jobs"
job() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$OUT/jobs"; }
compile_one() {  # compile_one <root> <source> <object> <flag set>
    local root="$1" src="$2" obj="$3" set="$4" inc
    case "$set" in
        util)   inc=("${INC_UTIL[@]}") ;;
        parser) inc=("${INC_PARSER[@]}" -Wno-extern-c-compat -Wno-unknown-pragmas) ;;
        dxmt)   inc=(-I"$root/src/dxmt" "${INC_DXMT[@]}") ;;
        d3d11)  inc=(-I"$root/src/airconv" -I"$root/src/d3d11" -I"$G" -I"$root/src/dxmt" -I"$D/src/airconv" -I"$D/src/winemetal" -I"$U" "${INC_BASE[@]}" -I"$OUT/gen") ;;
    esac
    case "$src" in
        *.c) "$CC" "${CFLAGS[@]}" -fmacro-prefix-map="$root/=" -fmacro-prefix-map="$D/=" "${inc[@]}" -c "$src" -o "$obj" ;;
        *)   "$CXX" "${CXXFLAGS[@]}" -fmacro-prefix-map="$root/=" -fmacro-prefix-map="$D/=" "${inc[@]}" -c "$src" -o "$obj" ;;
    esac > "$obj.err" 2>&1 || { echo "$src" >> "$OUT/failed"; return 1; }
}
run_jobs() {
    local w
    rm -f "$OUT/failed"
    for ((w = 0; w < JOBS; w++)); do
        ( awk -F'\t' -v w="$w" -v n="$JOBS" '(NR - 1) % n == w' "$OUT/jobs" | while IFS="$(printf '\t')" read -r root src obj set; do
              compile_one "$root" "$src" "$obj" "$set" || true
          done ) &
    done
    wait
    if [ -s "$OUT/failed" ]; then
        while read -r f; do
            o="$(awk -F'\t' -v s="$f" '$2 == s { print $3; exit }' "$OUT/jobs")"
            echo "=== $f"; grep -m 10 -A3 "error" "$o.err" || tail -20 "$o.err"
        done < "$OUT/failed"
        fail "compiling $(wc -l < "$OUT/failed" | tr -d ' ') file(s) failed, first $(basename "$(head -1 "$OUT/failed")")"
    fi
    while IFS="$(printf '\t')" read -r root src obj set; do
        [ -s "$obj" ] || fail "no object for $(basename "$src")"
    done < "$OUT/jobs"
}

# util_lib (src/util/meson.build: an aarch64 Windows host uses the headless
# wsi files), dxmt_lib (src/dxmt/meson.build) and DXBCParser
# (libs/DXBCParser/meson.build), each in source order.
UTIL_SRC=(util_env.cpp util_string.cpp util_bloom.cpp util_futex.cpp thread.cpp
          com/com_guid.cpp com/com_private_data.cpp config/config.cpp log/log.cpp
          sha1/sha1.c sha1/sha1_util.cpp
          wsi_monitor_headless.cpp wsi_window_headless.cpp wsi_platform_win32.cpp)
DXMT_SRC=(dxmt_format dxmt_names dxmt_command_queue dxmt_command dxmt_capture dxmt_info
          dxmt_device dxmt_buffer dxmt_texture dxmt_context dxmt_dynamic dxmt_staging
          dxmt_hud_state dxmt_allocation dxmt_presenter dxmt_sampler
          dxmt_resource_initializer dxmt_mem_census dxmt_bcn dxmt_shader_cache)
PARSER_SRC=(DXBCUtils BlobContainer ShaderBinary)
# src/d3d11/meson.build: d3d11_src, then d3d10_src.
D3D11_SRC=(d3d11/d3d11_class_linkage d3d11/d3d11_device d3d11/d3d11_input_layout
           d3d11/d3d11_inspection d3d11/d3d11_query d3d11/d3d11_shader
           d3d11/d3d11_state_object d3d11/d3d11_swapchain d3d11/d3d11_texture
           d3d11/d3d11_buffer d3d11/d3d11 d3d11/d3d11_resource_helper
           d3d11/d3d11_resource_view_helper d3d11/d3d11_texture_device
           d3d11/d3d11_texture_linear d3d11/d3d11_texture_dynamic
           d3d11/d3d11_resource_staging d3d11/dxmt_resource_binding d3d11/d3d11_pipeline
           d3d11/d3d11_pipeline_gs d3d11/d3d11_pipeline_ts d3d11/d3d11_enumerable
           d3d11/d3d11_pipeline_cache d3d11/d3d11_context_imm d3d11/d3d11_context_def
           d3d11/d3d11_multithread d3d11/d3d11_fence
           d3d10/d3d10_buffer d3d10/d3d10_device d3d10/d3d10_state_object
           d3d10/d3d10_texture d3d10/d3d10_util d3d10/d3d10_view)
obj_name() { echo "$1" | tr '/.' '__'; }

UTIL_OBJ=(); DXMT_OBJ=(); PLAIN_DXMT_OBJ=(); PARSER_OBJ=(); PLAIN_OBJ=(); PATCHED_OBJ=()
for s in "${UTIL_SRC[@]}"; do
    o="$OUT/obj/util_$(obj_name "$s").o"; job "$D" "$U/$s" "$o" util; UTIL_OBJ+=("$o")
done
for s in "${DXMT_SRC[@]}"; do
    o="$OUT/plain/obj/dxmt_$s.o"; job "$D" "$X/$s.cpp" "$o" dxmt; PLAIN_DXMT_OBJ+=("$o")
done
for s in "${PARSER_SRC[@]}"; do
    o="$OUT/obj/parser_$s.o"; job "$D" "$P/$s.cpp" "$o" parser; PARSER_OBJ+=("$o")
done
for s in "${D3D11_SRC[@]}"; do
    o="$OUT/plain/obj/$(obj_name "$s").o"; job "$D" "$D/src/$s.cpp" "$o" d3d11; PLAIN_OBJ+=("$o")
done
echo "compiling $(wc -l < "$OUT/jobs" | tr -d ' ') files, $JOBS at a time"
run_jobs
"$WINDRES" -i "$D/src/d3d11/version.rc" -o "$OUT/obj/version.o" 2>> "$OUT/build.err" || fail "windres version.rc failed"

# Thin archives in source order, as meson makes them ("csrDT"); the DXMT core
# twice, the submodule's for the unpatched DLL and the copy's for d3d11-src.dll.
"$AR" csrDT "$OUT/libutil.a" "${UTIL_OBJ[@]}"
"$AR" csrDT "$OUT/plain/libdxmt.a" "${PLAIN_DXMT_OBJ[@]}"
"$AR" csrDT "$OUT/libDXBCParser.a" "${PARSER_OBJ[@]}"

# meson: the d3d11/d3d10 objects in order, the resource, the module definition
# file, the dependency libraries in d3d11's dependency order (dxgi, DXBCParser,
# dxmt, winemetal, util), util_dep's -lntdll, -static (libc++ in, UCRT through
# api-ms-win-crt-*), file alignment 4096 and meson's default Windows libraries.
link_dll() {  # link_dll <output> <libdxmt.a> <objects...>
    local out="$1" dxmt="$2"; shift 2
    "$CXX" -shared -o "$out" "$@" "$OUT/obj/version.o" "$D/src/d3d11/d3d11.def" \
        "$OUT/libdxgi.a" "$OUT/libDXBCParser.a" "$dxmt" -L"$OUT" -lwinemetal "$OUT/libutil.a" -lntdll \
        -static -Wl,--file-alignment=4096 \
        -lkernel32 -luser32 -lgdi32 -lwinspool -lshell32 -lole32 -loleaut32 -luuid -lcomdlg32 -ladvapi32 \
        2>> "$OUT/build.err" || { grep -m 20 "error" "$OUT/build.err"; fail "linking $(basename "$out") failed"; }
}
link_dll "$OUT/plain/d3d11.dll" "$OUT/plain/libdxmt.a" "${PLAIN_OBJ[@]}"
cp "$OUT/jobs" "$OUT/baseline-jobs.tsv"

# Validate source delta before applying to the isolated copy. No wildcard patching.
python3 - "$QUEEN_RENDER_PATCH" <<'PY'
import subprocess,sys
rows=subprocess.check_output(['git','apply','--numstat',sys.argv[1]],text=True).splitlines()
allowed={'src/dxmt/dxmt_dynamic.cpp','src/d3d11/d3d11_shader.cpp','src/d3d11/d3d11_pipeline_gs.cpp','src/d3d11/d3d11_geometry_payload.hpp','src/airconv/airconv_public.h','src/airconv/dxbc_converter_gs.cpp'}
paths={row.split('\t')[2] for row in rows}
assert paths and paths<=allowed,('Review dependency coverage before broadening patch',paths)
PY
git -C "$OUT/tree" apply --check "$QUEEN_RENDER_PATCH"
git -C "$OUT/tree" apply "$QUEEN_RENDER_PATCH"
: "${QUEEN_DIAGNOSTICS_PATCHER:?exact reviewed diagnostics patcher path required}"
python3 "$QUEEN_DIAGNOSTICS_PATCHER" "$OUT/tree"
: > "$OUT/jobs"
PATCHED_OBJ=()
for s in "${D3D11_SRC[@]}"; do
    case "$s" in
        d3d11/d3d11_shader|d3d11/d3d11_pipeline_gs|d3d11/d3d11_device|d3d11/d3d11_context_imm|d3d11/d3d11_context_def)
            o="$OUT/obj/$(obj_name "$s").o"
            job "$OUT/tree" "$OUT/tree/src/$s.cpp" "$o" d3d11 ;;
        *) o="$OUT/plain/obj/$(obj_name "$s").o" ;;
    esac
    PATCHED_OBJ+=("$o")
done
job "$OUT/tree" "$OUT/tree/src/dxmt/dxmt_dynamic.cpp" "$OUT/obj/dxmt_dxmt_dynamic.o" dxmt
job "$OUT/tree" "$OUT/tree/src/dxmt/dxmt_mem_census.cpp" "$OUT/obj/dxmt_dxmt_mem_census.o" dxmt
run_jobs
cp "$OUT/jobs" "$OUT/candidate-jobs.tsv"
cp "$OUT/plain/libdxmt.a" "$OUT/libdxmt-queen.a"
"$AR" rcs "$OUT/libdxmt-queen.a" "$OUT/obj/dxmt_dxmt_dynamic.o" "$OUT/obj/dxmt_dxmt_mem_census.o"
link_dll "$OUT/d3d11-queen-render.dll" "$OUT/libdxmt-queen.a" "${PATCHED_OBJ[@]}"

# Preserve the real PE ABI and exact import library/symbol surface, not just DLL names.
for variant in stock baseline candidate; do
    case "$variant" in
        stock) image="$SHIP/d3d11.dll" ;;
        baseline) image="$OUT/plain/d3d11.dll" ;;
        candidate) image="$OUT/d3d11-queen-render.dll" ;;
    esac
    exports "$image" > "$OUT/$variant.exports"
    "$READOBJ" --coff-imports "$image" > "$OUT/$variant.imports.raw"
    "$READOBJ" --file-headers --coff-load-config --coff-exports "$image" > "$OUT/$variant.abi.txt"
    "$NM" --defined-only "$image" | sort > "$OUT/$variant.nm"
done
diff "$OUT/stock.exports" "$OUT/baseline.exports" || fail "baseline export set differs from shipped"
diff "$OUT/baseline.exports" "$OUT/candidate.exports" || fail "candidate export set changed"
python3 - "$OUT" <<'PY'
import hashlib,importlib.util,json,re,sys
from pathlib import Path
p=Path(sys.argv[1]);sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
repo=Path.cwd()
spec=importlib.util.spec_from_file_location('pe',repo/'tools/patch-wine-ntdll-sync.py')
pe=importlib.util.module_from_spec(spec);spec.loader.exec_module(pe)
images={'stock':repo/'app/Madeira/arm64ec-windows/d3d11.dll','baseline':p/'plain/d3d11.dll','candidate':p/'d3d11-queen-render.dll'}
parsed={label:pe.Pe(str(image)) for label,image in images.items()}
machines={image.machine for image in parsed.values()}
assert len(machines)==1 and machines<={0x8664,0xA641},('Mixed or unsupported PE machine',machines)
for label,image in parsed.items():
    assert any(kind==1 for _,_,kind in image.code_map()),('No ARM64EC CHPE code range',label)
def imports(label):
    # Ignore path/file header, addresses and thunks; retain every DLL + symbol/ordinal.
    text=(p/(label+'.imports.raw')).read_text()
    blocks=re.findall(r'Import\s*\{(.*?)\n\}',text,re.S)
    result=[]
    for block in blocks:
        names=re.findall(r'^\s*Name:\s*(.+)$',block,re.M)
        assert len(names)==1,('Malformed DLL import block',label)
        result.append((names[0].lower(),sorted(re.findall(r'^\s*Symbol:\s*(.+)$',block,re.M))))
    assert result,('No imports parsed',label)
    return sorted(result)
for label in ['stock','baseline','candidate']:
    abi=(p/(label+'.abi.txt')).read_text()
    ptr=re.search(r'CHPEMetadataPointer:\s*(0x[0-9a-fA-F]+)',abi)
    assert ptr and int(ptr.group(1),16),('Missing ARM64EC CHPE metadata',label)
assert imports('stock')==imports('baseline'),'Baseline import surface differs from stock'
baseline_imports=imports('baseline');candidate_imports=imports('candidate')
(p/'import-comparison.json').write_text(json.dumps({'baseline':baseline_imports,'candidate':candidate_imports,'identical':baseline_imports==candidate_imports},indent=2))
assert baseline_imports==candidate_imports,'Candidate import delta needs exact symbol/DLL review; see import-comparison.json'
report={'baseline_sha256':sha(p/'plain/d3d11.dll'),'candidate_sha256':sha(p/'d3d11-queen-render.dll'),
        'stock_baseline_symbol_layout_identical':(p/'stock.nm').read_text()==(p/'baseline.nm').read_text(),
        'incremental_units':['dxmt_dynamic.cpp','dxmt_mem_census.cpp','d3d11_shader.cpp','d3d11_pipeline_gs.cpp','d3d11_device.cpp','d3d11_context_imm.cpp','d3d11_context_def.cpp'],
        'diagnostics_scope':'BCD_QUEEN_RENDER_V2=1; explicit BCD_QUEEN_DIAGNOSTICS=1 opt-in',
        'exports_imports_verified':True,'pe_machine':hex(next(iter(machines))),'arm64ec_code_ranges_verified':True,'device_tested':False,'not_packaged':True}
(p/'receipt.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
PY
shasum -a256 -c "$OUT/stock-before.sha256"
test -z "$(git -C "$D" status --porcelain)" || fail "pristine DXMT modified"
echo "Queen-only alternative produced; no bundle copied, no game selector changed."
