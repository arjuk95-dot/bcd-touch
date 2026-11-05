# BCD 0.1.630 with the touch fork

Target upstream: **v0.1.630**, `53e7e8c73b62633b1d94c75b451fcc775928378f`, released 4 November 2026. [Release](https://github.com/thebcd69/bcd-games/releases/tag/v0.1.630). Upgrade branch: `wo-bcd-touch-001-v630`. The earlier `wo-bcd-touch-001` branch remains at the installed/tested source history.

The merge retains the version-3 pack format, per-game local presets, personal overrides, floating movement, displacement/timestamp Mouse Joystick, touch ownership, toggle/slide behavior, custom icons, free placement and editor dismissal. Their core source hashes are unchanged. Upstream's stock Look tab remains available for stock layouts.

The only source conflict was controller-slot reservation. The result retains a pack's forced reservation and sampling timer while accepting upstream's new per-game early-slot setting. The simulator publisher now tests default-off, per-game, forced-pack and no-input-source cases in separate fresh processes. Existing simultaneous movement/trigger/aim, neutral expiry, independent input and focus-loss checks remain.

The build recipe includes all 20 new upstream build/check steps and the modified Dock build. Omitted runtime dependencies now come from the fully SHA-pinned 0.1.630 release, including its changed kernelbase/setupapi variants and newly referenced opt-in libraries. The unchanged converter and 7-Zip files retain their hashes. No submodules are initialized or heavy engine builds run on the Windows PC.

The native archive and existing-slot packaging passed for app source **80c702a3dc1558c8ef8ab654070f845b97ec47b2**. The deliverable updates `com.thebcd69.bcd` using the existing signing account. It does not require uninstalling BCD or allocating another app slot. Before installing, back up the current settings, pack files and personal overrides with BCD closed. Keep the existing app's data when updating; do not reimport a default pack over personal edits.

Automated evidence:

- [SDK, worker, stock layout and stock sharing](https://github.com/arjunkl/bcd-touch/actions/runs/42037408518): passed.
- [45 simulator HUD/editor/store/restart exports](https://github.com/arjunkl/bcd-touch/actions/runs/42036500923): passed.
- [Production GamepadInput publisher and five startup-reservation cases](https://github.com/arjunkl/bcd-touch/actions/runs/42036506630): passed.
- [Pinned 0.1.630 runtime recovery](https://github.com/arjunkl/bcd-touch/actions/runs/42036512547): passed.
- [Complete macOS/Xcode archive and Wine/FEX runtime checks](https://github.com/arjunkl/bcd-touch/actions/runs/42039500455): passed.
- [Native existing-slot packaging and instruction/signature checks](https://github.com/arjunkl/bcd-touch/actions/runs/42064363458): passed.

The app source is identical between the simulator, SDK and final archive revisions; intervening commits update tests, documentation and CI. Simulator publisher tests use engine spies, not a running Windows game. iPad preview images use iPad geometry in an iPhone simulator, not a physical iPad. All 0.1.630 installation, signing, JIT, guest and physical playtests remain pending. The previous installed version's physical results do not establish those results for this update.

The first archive attempt stopped before compilation because an upstream check referenced a missing `docs/BINARIES-WOW64.md`. That reference inventory was restored from the verified 0.1.630 release, with its provenance labelled. The retry requires the i386 farm build to succeed and independently checks all 26 command tools as actual x86 PE files, both after the build and in the produced IPA.

To reproduce, check out the branch and dispatch `.github/workflows/touch-ipa.yml` on `macos-15-intel`; it selects Xcode 26.3 and initializes/builds the pinned submodules on CI. After success, dispatch `touch-sideload-packages.yml` with that run ID, the exact embedded source commit and the raw IPA's SHA-256. For this build those are `42039500455`, `80c702a3dc1558c8ef8ab654070f845b97ec47b2` and `841eac67019bee81c0920d314464e8d2900f48350302f80090240e6b59463a84`. Choose the `BCD-Touch-existing-update` artifact for the regular BCD installation. It still needs personal signing through SideStore. The earlier branch and verified b78e960 IPA remain available for rollback.

Current build/test evidence: [integration receipt](receipts/touch/upstream-v630/integration.json). The installed phone remains on b78e960 until the new package is signed and installed.

Verified deliverable: `BCD-Touch-v630-80c702a.ipa`, 186,050,026 bytes, SHA-256 `d8ed04c1fbb1a7cc26474bb5772c31d859abcf1f525770fb2865598e834d0722`. [Package receipt](receipts/touch/upstream-v630/existing-update-package.json). Its signature is prepared for re-signing; SideStore must still apply the owner's personal signature. No device installation or data-preservation result is claimed by this package receipt.
