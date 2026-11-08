# Noita startup and cursor update

App source: `f9e5bec1650351d108c0bb5336330188c5d950d2` on
`wo-bcd-noita-workshop-001`, based on
`99f5eb9dd481551e4a928d3e4a84093cce6060fc`.
Upstream base remains v0.1.630, `53e7e8c73b62633b1d94c75b451fcc775928378f`.

## What this update changes

Relative cursor packs now receive Wine's actual clipped cursor position in
BCD Dock's desktop launch route. The compositor follows that position instead
of leaving its arrow at the previous location. Touch-down and retouch still
send no absolute move. The additional reporting is enabled only while a cursor
pack is active; stock desktop mouse routing retains its existing behavior.

The existing 32-bit execution failure report can capture up to 512 bytes of a
nearby generated-code allocation. It only reads an already registered executable
alias, stops at its mapping boundary and labels the register as a candidate,
not a proven caller. It does not change exception handling or guest execution.

The OpenGL libraries are byte-identical to the previous verified export.
Noita's pack, Dread's reviewed pack, pack loading, regeneration and personal-edit
merging are unchanged. See `receipts/noita-startup/preservation.json`.

## Observed results and remaining work

- Earlier Workshop stalls occurred with Steam explicitly offline. The owner
  subsequently reached Noita's main menu on Wi-Fi. No subscriptions or mod
  configuration were changed, and no download completion was fabricated. The
  particular Workshop item remains unidentified.
- Two Wi-Fi runs crashed after choosing Continue, with error `0xC0000096` at
  guest address `0xfff40048`, in NTDLL's DOS header. A nearby LuaJIT code allocation
  ends at `0xfff40000`. The supplied `lua51.dll` is LuaJIT 2.0.4 and its computed
  FEX code-map ID exactly matches the logged module. This identifies the code
  involved; the cause of the bad jump is still unresolved.
- The compiled cursor regression covers relative movement, clipping, click
  continuity, guest warps and the stock routes. The generated-code capture has
  compiled boundary and invalid-candidate checks. Existing touch, controller,
  pack/schema, UIKit and OpenGL checks passed.
- Native archive run `42191403792` and existing-slot package run `42204232781`
  passed. Packaging preserved the executable instruction hashes.
- On 7 November, the owner restored the original Dread layout by choosing
  **Use generated controls next launch**. This was a selection recovery; it
  required no app update or phone-file edits by the agent.
- This new IPA has not been physically tested. Noita menu cursor use, Continue,
  actual gameplay and the new fault capture still require an iPhone test.
  This update does **not** claim to fix the Continue crash.

## Install and test

The IPA targets the existing `com.thebcd69.bcd` app and its usual helpers.
Save any running game and close BCD. Download the IPA to Files, then select it
through SideStore → My Apps → + using the same signing account to update BCD.
Personal signing still happens in SideStore.

Enable JIT using the established setup. Launch Noita through BCD Dock on Wi-Fi.
In pointer mode, swipe to place the cursor over Continue, then tap
**Select / drag**. Check whether the cursor follows the swipe and the click
selects the intended menu item. If Continue crashes again, export that run's
Noita session log from BCD's `logs` folder before another launch.

The earlier `env.FEX_MULTIBLOCK = 0` experiment belongs in Noita → Options →
Game config. Its result has not been reported. If it is used, record it with
the test; removing only that line undoes the experiment.

## Build and export

Use `.github/workflows/touch-ipa.yml` on this branch with
`runner=macos-15-intel` and `gl_dependency_run=42111988021`. The native build uses
the existing pinned submodules, Xcode 26.3 and source-built graphics dependencies.
For the verified build above, the raw IPA SHA-256 is
`d12c1c66c63d87423aac6c7a96ded77263e3d6f559846e9cd4211151849f0ae3`.

Export with `.github/workflows/touch-sideload-packages.yml`, explicitly setting
`source_run=42191403792`, `source_commit=f9e5bec1650351d108c0bb5336330188c5d950d2`
and that raw SHA-256. The verified existing-slot IPA is 191,852,312 bytes, SHA-256
`0035e6e47735985d165bee904475f83017b58e97eff3e560669ecc704014c44f`.
