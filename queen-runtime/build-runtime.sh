#!/bin/bash
set -euo pipefail
ORCH="$GITHUB_WORKSPACE/queen-runtime"
cd "$GITHUB_WORKSPACE/source"
test "$(git rev-parse HEAD)" = e5b9da7de835b02c0ecd229ef3b921a061545e51
# Retained native verification compares immutable source trees, not working files.
git fetch --no-tags --depth 1 origin 2833ed85d945bb6623611200b558057f36f60f20
git apply --check "$ORCH/app.patch"
git apply "$ORCH/app.patch"
git submodule update --init --recursive --depth 1 --jobs 4 FEX dxmt
mkdir -p build-out ../inputs
# All release inputs are existing emulator/runtime artifacts, never retail game files.
if [ "$GITHUB_REPOSITORY" = arjuk95-dot/bcd-touch ]; then
  gh api repos/arjuk95-dot/bcd-touch/actions/artifacts/13955942602/zip > ../inputs/donor.zip
  gh api repos/arjuk95-dot/bcd-touch/actions/artifacts/14055382553/zip > ../inputs/retained-native-inputs.zip
  gh api repos/arjuk95-dot/bcd-touch/actions/artifacts/14055382553 > ../inputs/retained-artifact-metadata.json
  gh api repos/arjuk95-dot/bcd-touch/actions/runs/43453839217 > ../inputs/retained-run-metadata.json
  gh api repos/arjuk95-dot/bcd-touch/actions/jobs/131982686963 > ../inputs/retained-job-metadata.json
else
  test "$GITHUB_REPOSITORY" = arjuk7/bcd-ios-builds
  gh release download bcd-retained-v653-native654-v1 --repo "$GITHUB_REPOSITORY" --dir ../inputs --pattern donor.zip --pattern retained-native-inputs.zip --pattern 'retained-*-metadata.json'
fi
echo '76d08cd7331319657162f15ec4fc6fd41abdd299687b7d3d230d540d18f50d0f  ../inputs/donor.zip' | shasum -a256 -c -
echo '8f35e438c0814a3bfe4775089db2a7d6a84858aa161c9aea0d4c667f42d8e4ea  ../inputs/retained-native-inputs.zip' | shasum -a256 -c -
test -d /Applications/Xcode_26.3.app
sudo xcode-select -s /Applications/Xcode_26.3.app/Contents/Developer
python3 tools/touch-packs/reuse-v653-donor.py prepare --artifact ../inputs/donor.zip --output build-out/donor
python3 tools/touch-packs/reuse-v653-donor.py stage --prepared build-out/donor --repo "$PWD"
python3 tools/ci/restore-native-link-inputs.py --artifact ../inputs/retained-native-inputs.zip --artifact-metadata ../inputs/retained-artifact-metadata.json --run-metadata ../inputs/retained-run-metadata.json --job-metadata ../inputs/retained-job-metadata.json --repo "$PWD" --receipt build-out/native-link-inputs.json
# One verified native object; every unrelated retained member stays byte-identical.
python3 queen-system-candidate/queen-native-candidate/compile-one-object.py --repo "$PWD" --output "$PWD/build-out/queen-native"
# Optional compiled native game-workload lane from the delivered 667 artifact.
# A private runner may lack permission to read a public repository's action artifact.
# In that case reference remains useful, and the unavailable lane is disabled in UI.
if gh api repos/arjuk95-dot/bcd-touch/actions/artifacts/14329248488/zip > ../inputs/native667.zip; then
  echo 'ec7a3df89deea5260fe5f1649ed8b55fa7aa494e310c02853d9e55f8ba7fdc8f  ../inputs/native667.zip' | shasum -a256 -c -
  python3 "$ORCH/extract-native.py" ../inputs/native667.zip app/Madeira/arm64ec-windows/xtajit64-queen-nav.dll
else
  echo 'Native comparison artifact unavailable; reference lane will be packaged.'
fi
python3 tools/stikjit-interface-compat.py app/Frameworks/StikJIT.xcframework
python3 - <<'PY'
import datetime,os,plistlib
from pathlib import Path
p=Path('app/Madeira/Info.plist');d=plistlib.loads(p.read_bytes())
d.update(MadeiraCommit=os.environ['GITHUB_SHA'],MadeiraRepo=os.environ['GITHUB_REPOSITORY'],MadeiraBuilt=datetime.datetime.now(datetime.timezone.utc).isoformat())
p.write_bytes(plistlib.dumps(d,sort_keys=False))
PY
xcodebuild -project app/Madeira.xcodeproj -scheme Madeira -sdk iphoneos -configuration Release SWIFT_OPTIMIZATION_LEVEL=-O GCC_OPTIMIZATION_LEVEL=3 CODE_SIGNING_ALLOWED=NO archive -archivePath build-out/QueenRuntime.xcarchive > build-out/archive.log 2>&1 &
archive_pid=$!
# Report bounded compiler activity without changing archive flags or outputs.
while kill -0 "$archive_pid" 2>/dev/null; do
  sleep 45
  if kill -0 "$archive_pid" 2>/dev/null; then
    echo 'Archive progress (pid, parent, elapsed, CPU percent, resident KB, executable):'
    ps -axo pid=,ppid=,etime=,pcpu=,rss=,comm= | awk -v pid="$archive_pid" '$1 == pid || $NF ~ /(^|\/)(swift-frontend|clang|clang\+\+|ld|metal|actool|ibtool|XCBBuildService)$/ {print}' | head -20 || true
    wc -c build-out/archive.log
    tail -3 build-out/archive.log | cut -c 1-220
  fi
done
wait "$archive_pid" || { tail -160 build-out/archive.log; exit 1; }
python3 "$ORCH/package-runtime.py" "$PWD"
