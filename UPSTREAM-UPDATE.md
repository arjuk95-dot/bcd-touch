# BCD 0.1.630 with the touch fork

Target upstream: **v0.1.630**, `53e7e8c73b62633b1d94c75b451fcc775928378f`, released 4 November 2026. [Release](https://github.com/thebcd69/bcd-games/releases/tag/v0.1.630). Upgrade branch: `wo-bcd-touch-001-v630`. The earlier `wo-bcd-touch-001` branch remains at the installed/tested source history.

The merge retains the version-3 pack format, per-game local presets, personal overrides, floating movement, displacement/timestamp Mouse Joystick, touch ownership, toggle/slide behavior, custom icons, free placement and editor dismissal. Their core source hashes are unchanged. Upstream's stock Look tab remains available for stock layouts.

The only source conflict was controller-slot reservation. The result retains a pack's forced reservation and sampling timer while accepting upstream's new per-game early-slot setting. The simulator publisher now tests default-off, per-game, forced-pack and no-input-source cases in separate fresh processes. Existing simultaneous movement/trigger/aim, neutral expiry, independent input and focus-loss checks remain.

The build recipe includes all 20 new upstream build/check steps and the modified Dock build. Omitted runtime dependencies now come from the fully SHA-pinned 0.1.630 release, including its changed kernelbase/setupapi variants and newly referenced opt-in libraries. The unchanged converter and 7-Zip files retain their hashes. No submodules are initialized or heavy engine builds run on the Windows PC.

SDK, stock-layout/share compatibility, 45-image simulator/store/restart, production publisher and base-runtime checks precede the full native archive. The deliverable will update the existing BCD bundle slot, preserving its container and the installed pack/override files. Before installation, current settings and controls need a fresh bounded backup; signing and physical checks follow the verified package. No phone configuration changes are made during the source merge.

Current build/test evidence: [integration receipt](receipts/touch/upstream-v630/integration.json). The installed phone remains on b78e960 until the new package is signed and installed.
