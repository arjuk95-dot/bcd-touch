link_dll "$OUT/plain/d3d11.dll" "$OUT/plain/libdxmt.a" "${PLAIN_OBJ[@]}"
cp "$OUT/jobs" "$OUT/baseline-jobs.tsv"

# Validate source delta before applying to the isolated copy. No wildcard patching.
python3 - "$QUEEN_RENDER_PATCH" <<'PY'
import subprocess,sys
rows=subprocess.check_output(['git','apply','--numstat',sys.argv[1]],text=True).splitlines()
allowed={'src/d3d11/d3d11_context_imm.cpp','src/d3d11/d3d11_context_impl.cpp','src/d3d11/d3d11_context_def.cpp'}
paths={row.split('\t')[2] for row in rows}
assert paths and paths<=allowed,('Review dependency coverage before broadening patch',paths)
PY
git -C "$OUT/tree" apply --check "$QUEEN_RENDER_PATCH"
git -C "$OUT/tree" apply "$QUEEN_RENDER_PATCH"
: > "$OUT/jobs"
PATCHED_OBJ=()
for s in "${D3D11_SRC[@]}"; do
    case "$s" in
        d3d11/d3d11_context_imm|d3d11/d3d11_context_def)
            o="$OUT/obj/$(obj_name "$s").o"
            job "$OUT/tree" "$OUT/tree/src/$s.cpp" "$o" d3d11 ;;
        *) o="$OUT/plain/obj/$(obj_name "$s").o" ;;
    esac
    PATCHED_OBJ+=("$o")
done
run_jobs
cp "$OUT/jobs" "$OUT/candidate-jobs.tsv"
link_dll "$OUT/d3d11-queen-render.dll" "$OUT/plain/libdxmt.a" "${PATCHED_OBJ[@]}"

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
        'incremental_units':['d3d11_context_imm.cpp','d3d11_context_def.cpp'],
        'exports_imports_verified':True,'pe_machine':hex(next(iter(machines))),'arm64ec_code_ranges_verified':True,'device_tested':False,'not_packaged':True}
(p/'receipt.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
PY
shasum -a256 -c "$OUT/stock-before.sha256"
test -z "$(git -C "$D" status --porcelain)" || fail "pristine DXMT modified"
echo "Queen-only alternative produced; no bundle copied, no game selector changed."
