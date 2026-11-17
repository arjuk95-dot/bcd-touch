#!/bin/bash
set -euo pipefail
ORCH="$GITHUB_WORKSPACE/queen-system-candidate"
cd "$GITHUB_WORKSPACE"
mkdir inputs
# All inputs originate from this already-public repository. No private tokens,
# retained source bundle, personal logs, or cross-account downloads are used.
test "$GITHUB_REPOSITORY" = arjuk95-dot/bcd-touch
test "$(gh api "repos/$GITHUB_REPOSITORY" --jq '.private')" = false
gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/13955942602/zip" > inputs/donor.zip
gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/14055382553/zip" > inputs/retained-native-inputs.zip
echo '76d08cd7331319657162f15ec4fc6fd41abdd299687b7d3d230d540d18f50d0f  inputs/donor.zip' | shasum -a256 -c -
echo '8f35e438c0814a3bfe4775089db2a7d6a84858aa161c9aea0d4c667f42d8e4ea  inputs/retained-native-inputs.zip' | shasum -a256 -c -
gh api "repos/$GITHUB_REPOSITORY/actions/artifacts/14055382553" > inputs/retained-artifact-metadata.json
gh api "repos/$GITHUB_REPOSITORY/actions/runs/43453839217" > inputs/retained-run-metadata.json
gh api "repos/$GITHUB_REPOSITORY/actions/jobs/131982686963" > inputs/retained-job-metadata.json
# Checkout this reviewed public source commit directly: ordinary auditable files,
# never a private bundle or opaque compressed patch.
git clone --filter=blob:none --no-checkout https://github.com/arjuk95-dot/bcd-touch.git source
git -C source fetch origin "$GITHUB_SHA" 2833ed85d945bb6623611200b558057f36f60f20
git -C source checkout --detach "$GITHUB_SHA"
python3 - <<'VERIFY'
import hashlib,json
from pathlib import Path
r=Path('source');m=json.loads(Path('queen-system-candidate/public-source-manifest.json').read_text())
for n,h in m['files'].items():
 assert hashlib.sha256((r/n).read_bytes()).hexdigest()==h,n
VERIFY
git -C source submodule update --init --recursive --depth 1 --jobs 4 FEX dxmt wine
cd source
mkdir -p build-out toolchains
# Exact previous compiler; do not silently substitute Xcode27.
test -d /Applications/Xcode_26.3.app
sudo xcode-select -s /Applications/Xcode_26.3.app/Contents/Developer
python3 tools/touch-packs/reuse-v653-donor.py prepare --artifact ../inputs/donor.zip --output build-out/donor
python3 tools/touch-packs/reuse-v653-donor.py stage --prepared build-out/donor --repo "$PWD"
python3 tools/ci/restore-native-link-inputs.py --artifact ../inputs/retained-native-inputs.zip --artifact-metadata ../inputs/retained-artifact-metadata.json --run-metadata ../inputs/retained-run-metadata.json --job-metadata ../inputs/retained-job-metadata.json --repo "$PWD" --receipt build-out/native-link-inputs.json
curl -fL --retry 2 https://github.com/mstorsjo/llvm-mingw/releases/download/20260421/llvm-mingw-20260421-ucrt-macos-universal.tar.xz -o ../inputs/mingw.tar.xz
echo 'bd85a3975723815cef28dbbd2ca2cb0c926f6b348a12a0453f39f7af273cb3f7  ../inputs/mingw.tar.xz' | shasum -a256 -c -
tar -xJf ../inputs/mingw.tar.xz -C toolchains
export MINGW="$PWD/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
command -v cmake >/dev/null; command -v ninja >/dev/null
# Native header prerequisites are rebuilt only from the retained Wine pin.
export PATH="$(brew --prefix llvm)/bin:$(brew --prefix lld)/bin:$PATH"
bash "$ORCH/queen667/prepare-wine-headers.sh"
python3 "$ORCH/queen667/build-floor-native.py" "$PWD"
python3 "$ORCH/queen667/diagnostics/gate-copy.py" "$ORCH"
python3 "$ORCH/build-target.py" "$ORCH"
export QUEEN_RENDER_PATCH="$ORCH/queen-render-v2.patch"
export QUEEN_DIAGNOSTICS_PATCHER="$ORCH/queen667/renderer/apply-production-diagnostics.py"
bash "$ORCH/render-build/build-queen-render.sh"
# Preserve prior659 DXMT object, not just old654 retained archive.
python3 "$ORCH/queen-native-candidate/compile-one-object.py" --repo "$PWD" --output "$PWD/build-out/queen-native"
# Matched compiler half: keep every other retained native archive member.
bash "$ORCH/prepare-llvm-headers.sh" > build-out/llvm-headers.log 2>&1 || { tail -120 build-out/llvm-headers.log; exit 1; }
python3 "$ORCH/prepare-native-gs.py" "$ORCH" > build-out/native-gs-source.log 2>&1 || { tail -120 build-out/native-gs-source.log; exit 1; }
python3 "$ORCH/replace-airconv-gs.py" --repo "$PWD/build-out/queen-gs-native-source" --archive "$PWD/app/Madeira/libdxmt_combined.a" --output "$PWD/build-out/queen-gs-native"
cp build-out/queen-gs-native/libdxmt_combined-gs.a app/Madeira/libdxmt_combined.a
# Public667 deliberately keeps the exact verified donor kernelbase.dll.
# The rejected TLS binary rewrite is omitted; guest-leaf body checks fail closed
# and retain the original runtime APIs when their optimized body is absent.
git apply --check "$ORCH/queen-nav-app-and-badge.patch"
git apply "$ORCH/queen-nav-app-and-badge.patch"
python3 "$ORCH/apply-queen-render-app.py" "$PWD"
python3 "$ORCH/apply-render-v2-selection.py" "$PWD"
python3 "$ORCH/queen667/diagnostics/apply-profile.py" "$PWD"
git apply --check "$ORCH/inscryption-lower-left.patch"
git apply "$ORCH/inscryption-lower-left.patch"
python3 tools/stikjit-interface-compat.py app/Frameworks/StikJIT.xcframework
python3 - <<'PY'
import datetime,os,plistlib
from pathlib import Path
p=Path('app/Madeira/Info.plist');d=plistlib.loads(p.read_bytes());d.update(CFBundleVersion='667',CFBundleShortVersionString='0.1.667',MadeiraCommit=os.environ['GITHUB_SHA'],MadeiraRepo=os.environ['GITHUB_REPOSITORY'],MadeiraBuilt=datetime.datetime.now(datetime.timezone.utc).isoformat(),BCDDeviceValidationStatus='NOT_RUN',BCDFullValidationRunStatus='NOT_RUN');p.write_bytes(plistlib.dumps(d,fmt=plistlib.FMT_XML,sort_keys=False))
PY
xcodebuild -project app/Madeira.xcodeproj -scheme Madeira -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO -showBuildSettings > build-out/release-build-settings.txt
python3 - <<'CHECK'
from pathlib import Path
s=Path('build-out/release-build-settings.txt').read_text()
assert 'SWIFT_OPTIMIZATION_LEVEL = -Onone' not in s
assert 'GCC_OPTIMIZATION_LEVEL = 0' not in s
assert 'SWIFT_OPTIMIZATION_LEVEL = -O' in s
CHECK
xcodebuild -project app/Madeira.xcodeproj -scheme Madeira -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO archive -archivePath build-out/Madeira.xcarchive > build-out/archive.log 2>&1 || { tail -150 build-out/archive.log; exit 1; }
python3 tools/touch-packs/reuse-v653-donor.py assemble --prepared build-out/donor --compiled-app build-out/Madeira.xcarchive/Products/Applications/Madeira.app --source "$GITHUB_SHA" --app-repository "$GITHUB_REPOSITORY" --output build-out/reused
python3 tools/touch-packs/reuse-v653-donor.py verify --output build-out/reused
python3 "$ORCH/package-candidate.py" "$ORCH"
codesign --verify --deep --strict build-out/reused/Payload/Madeira.app
(cd build-out/reused && zip -qry ../BCD-667-Queen-System-unsigned.ipa Payload)
source_sha=$(shasum -a256 build-out/BCD-667-Queen-System-unsigned.ipa | awk '{print $1}')
# Preserve the installed com.thebcd69.bcd slot; raw donor is com.arjunkl.bcdtouch.
python3 tools/touch-packs/package-sideload.py build-out/BCD-667-Queen-System-unsigned.ipa --mode existing --output build-out/existing-update --expected-source "$GITHUB_SHA" --expected-ipa-sha "$source_sha"
cp build-out/existing-update/BCD-Touch-update-existing-unsigned.ipa build-out/BCD-667-Queen-System-update.ipa
shasum -a256 build-out/BCD-667-Queen-System-update.ipa > build-out/ipa.sha256



