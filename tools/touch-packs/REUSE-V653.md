# Touch-only v653 donor route

This is a **new, locally tested packaging helper**, not a completed native build
or a phone validation. It preserves the delivered fork runtime and changes only
the main app executable plus bounded build/validation metadata. Touch gestures
need compiled Swift/UIKit code; JSON injection is not a substitute.

## Exact donor

`arjuk95-dot/bcd-touch`, successful run `43227989116`, source
`37815c32296179231362a2aa645eba54827f0f2f`, raw artifact `13955942602`.
The artifact and nested IPA have different SHA-256 hashes. Both, the generated
catalog, and the complete 1,360-file payload inventory are pinned in
`v653-donor.json`. The catalog came from the raw workflow artifact, not a guessed
regeneration with different source coverage.

The inspected IPA is `com.arjunkl.bcdtouch`, version `0.1.653` / build `653`,
Xcode `2630`, SDK `iphoneos26.2`. It contains the three Windows DLL farms,
Mesa/MoltenVK, Vulkan, D3D12 converter, Dock, helper extensions, StikJIT, resources
and license notices. It contains **no bundled wine-mono directory**. Do not invent
one or claim Mono was lost by this route. The delivered build labels broad tests
pending and device testing not run; successful download does not upgrade those.

## Workflow integration

Use the existing branch with proven cache hits, `wo-bcd-profiles-native-001`.
GitHub caches are branch scoped. Restore exact keys with `fail-on-cache-miss:
true`; do not start LLVM/FFmpeg/FEX compilation after a miss. The workflow owner
must supply reviewed native prerequisites and five-final-archive build steps.
This helper does not dispatch or rebuild anything.

```sh
python3 tests/host/check-v653-donor-reuse.py
# Download *artifact ZIP*, not action/download-artifact's extracted directory.
# gh api repos/arjuk95-dot/bcd-touch/actions/artifacts/13955942602/zip > donor.zip
python3 tools/touch-packs/reuse-v653-donor.py prepare \
  --artifact donor.zip --output build-out/donor
python3 tools/touch-packs/reuse-v653-donor.py stage \
  --prepared build-out/donor --repo "$GITHUB_WORKSPACE"
```

`prepare` writes only a fresh directory; it refuses wrong hashes, unexpected app
identity, path traversal, case collisions, symlinks, special/encrypted entries,
oversized archives and personal provisioning profiles. `stage` overwrites only
the explicitly enumerated app resources, the generated config catalog and the
prebuilt iOS StikJIT framework. It also applies the same one-line converter
source-hash to released-hash substitution used by the successful donor build,
with pinned provenance checks, and records its receipt in build-out. Do not run
the old stage-converter.py as well; that would download the same dependency again.
It does not copy the old app executable, headers,
Swift sources or any new engine binary into the source tree. Extra old resource
files in the checkout cannot leak into the final app: assembly starts from the
verified donor, not the newly built app's resource directory.

Then restore/build the required native **static link inputs**, run focused native
Swift/UIKit checks (including the changed Tenebris Inventory latch fixture), and
archive the app with the same supported Xcode SDK/configuration. Do not skip the
new renderer fixture using the previous source's unchanged-evidence gate.

Missing final archives were `libntdll_unix.a`, `libwin32u_unix.a`,
`libwineserver.a`, `libdxmt_combined.a`, `libmadeira_rppairing.a`.
These require matching source/configure/generated headers and static prerequisites,
including FreeType for win32u. Calling them five final archives does not justify
omitting FreeType and silently disabling fonts. Also restore the matching seven
FEX and four FFmpeg archives and the four tracked crypto archives. No PE DLL farm,
Mesa/MoltenVK, Dock or LLVM rebuild belongs in this lane.

```sh
python3 tools/touch-packs/reuse-v653-donor.py link-inputs \
  --repo "$GITHUB_WORKSPACE" --output build-out/native-link-inputs.json
# On Mac, additionally xcrun lipo -verify_arch arm64 each of the 20 recorded files.
# Retain those archives, generated headers, exact source/configuration/toolchain
# evidence and this manifest as an artifact for the next true app-only update.

python3 tools/touch-packs/reuse-v653-donor.py assemble \
  --prepared build-out/donor \
  --compiled-app build-out/Madeira.xcarchive/Products/Applications/Madeira.app \
  --source "$GITHUB_SHA" --output build-out/reused
python3 tools/touch-packs/reuse-v653-donor.py verify --output build-out/reused
```

The new app must be thin arm64, match the expected source and bundle identity,
and have the same dynamic dependency set and non-build Info.plist capabilities
as the donor. A difference fails closed for review. It cannot silently switch
bundle IDs, callback URLs, minimum OS or other capabilities. New artwork or
resource changes would need an explicit extension of this route. The current
approved touch diff changes neither artwork nor resource files.

Assembly reuses all donor files except `Madeira`, `Info.plist`, and the now-invalid
**main** `_CodeSignature` seal. It keeps helper/framework/runtime binaries and
nested signatures byte-identical. `reuse-receipt.json` records every final file;
`verify` must run **before signing**, since signing legitimately alters executable
signatures and seals. The helper does not claim post-signing byte identity.

Then use the existing `ota-variants.py` **fakesign function only** on
`build-out/reused/Payload/Madeira.app`, verify codesign, zip `Payload`, and invoke
`tools/touch-packs/package-sideload.py --mode existing` with the new IPA hash and
source commit. That existing packager keeps main/helper bundle identifiers and
requested JIT/memory entitlements coherent. Do not call the OTA publisher or
install anything as a side effect. Report pre-sign reuse evidence separately
from native compile, focused tests, broad regressions and physical phone tests.
