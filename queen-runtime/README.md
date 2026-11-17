# Queen's Domain separate runtime

This is an implementation candidate, not a measured performance result. Target: approximately 60 real FPS at 1440x800 on iPhone 16 Pro Max. No claim that the target is currently achieved.

## Foundation

App source: delivered public 667 source e5b9da7de835b02c0ecd229ef3b921a061545e51. Runtime default: hash-verified 653 donor, retained 654 native link inputs, exact verified 659 dxmt_dynamic.o update. This is a conservative reference, not a statistically established fastest version. Existing scene/thermal/resolution differences prevent ranking 659/660/667 by their headline FPS.

No 661 alias-cache experiment, 663 readback batching, 660 TLS DLL rewrite, geometry-payload experiment, navigation offload, or native ntdll-sync mode is enabled by the default lane. Optional native render uses the compiled FEX DLL from actual delivered 667, with its shader-state and whole five-stage resource-commit workload replacements. Hooks still require their original exact image/function checks. This lane is unproven and disabled by default. Its presence must not be described as an optimization gain.

## Actual changes

Separate bundle com.arjunkl.queensdomain.runtime and helper identities; separate queensdomainruntime URL scheme, including JIT shortcut and LocalDevVPN callbacks. Queen-only launch gate, direct game-folder copy into a new path, retained existing in-game touch controls, and a persistent runtime choice that must be selected before the first launch in a process. Original BCD container, original checkout and game data are not edited by these changes.

Native bridge reasserts the selected lane after per-game/global environment files are read. Frame generation, failed readback batching and known-crashing native ntdll-sync mode are off. Reference and native render use the same stock renderer and host archives, so the comparison does not mix the 667 shader-payload experiment into one side.

Whole-frame measurement reuses the existing Present ring; it adds no new per-frame hooks. One timer per second waits for the first present, allows 60 seconds to warm up, then collects 30 seconds of frame intervals with CPU and thermal context. Median, p95, maximum, actual frames per wall-second, trailing silence and ring-loss counts are retained. Background interruption marks the window invalid. This does not measure translation self-time, native hook cost, GPU occupancy or GPU execution separately from queue waits. Existing renderer logs must be aligned to the same interval; do not sum overlapping CPU/GPU metrics.

## Build

Builds use the existing public source build repository and its already-published emulator/runtime artifacts; the private recipe remains available. No private release input is used by the public job. No retail executable, PAK, save, phone log or private game asset is uploaded. Restore retained native archives and compile only the verified 659 object plus the app. Reuse the delivered compiled optional FEX component when accessible. No emulator rebuild and no duplicate workflow dispatch.

The app is compiled with Release / Swift -O / C-family -O3. Packaging checks all donor runtime files, app/helper IDs, required memory/JIT entitlements and deep code signatures. The resulting IPA is ad-hoc signed and needs normal personal sideload signing. Compile/package checks are not phone launch, save migration, graphics correctness or performance validation.

## Minimal next phone evidence

Use one existing save and fixed camera/action sequence, frame generation off, same runtime lane and cool-start state. First reference at 1168x536, then 1440x800; close the app between runs. Capture the logs and Documents/logs/queen-runtime JSON/CSV files. Repeat native render at one matched resolution only if reference logs and native activation confirm a useful render-thread opportunity. Need matched frame times, render submission/readback cost and thermal context before choosing a further targeted change.

The new bundle cannot read the existing BCD container directly under iOS sandboxing. Game-folder import copies game files only. Existing saves and personal layouts require the copy-only transfer helper or a reviewed equivalent backup restore. Do not present game-folder import as save migration.

The copy-only transfer helper has six synthetic integrity and overwrite-protection checks. It has not transferred a real phone save. Use export with --game-root Games/QueensDomain, keep the local backup private, and restore only into a fresh, still-closed separate runtime app. Existing destination files are always refused.
