#!/usr/bin/env python3
"""Evaluate the unchanged build recipe's actual hash inputs before compiling."""
from pathlib import Path
import hashlib
import subprocess

root = Path(__file__).resolve().parents[2]
recipe = (root / 'build/dxmt-ios/build.sh').read_text()
start = recipe.index('    converter_id_inputs() {')
end = recipe.index('\n    CONVERTER_ID=', start)
function = recipe[start:end]
assert function.count('converter_id_inputs()') == 1
out = root / 'build-out'
out.mkdir(exist_ok=True)
script = '''set -euo pipefail
REPO_ROOT="$PWD"
BUILD_DIR="$PWD/build/dxmt-ios"
DXMT_ROOT="$PWD/dxmt"
DXMT_SRC="$PWD/dxmt/src"
LLVM_BUILD="$PWD/toolchains/llvm-ios-build"
source build/madeira-d3d12/deps.sh >&2
''' + function + '\nconverter_id_inputs\n'
manifest = subprocess.check_output(['bash', '-c', script], cwd=root)
(out / 'converter-input-manifest.txt').write_bytes(manifest)
identity = hashlib.sha256(manifest).hexdigest()[:16]
(out / 'converter-identity.txt').write_text(identity + '\n')
print('Exact donor converter input identity:', identity, flush=True)
assert b'absent ' not in manifest, 'Missing converter hash input'
assert identity == '74ba675a4c281a8b', 'Donor converter inputs differ; see persisted per-file manifest'
