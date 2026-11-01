# WO-BCD-TOUCH-001 test fork

Base: BCD **v0.1.626**, `adc9cc742f52601a42f52ac6b4fbcc701bdb16ad`. The earlier local v0.1.623 checkout was clean and had no touch branch. Work continued in a separate checkout and the branch `wo-bcd-touch-001` at https://github.com/arjunkl/bcd-touch.

The app identity is `com.arjunkl.bcdtouch`, display name **BCD Touch Lab**, with an original teal touch/swipe icon and isolated `bcdtouchlab://` callback URLs. Helper extension IDs derive from that identity; MemoryHost has its own matching identifier. No installed app, signing profile, JIT pairing, game or save was modified. A new identity does **not** automatically share BCD's data container: use a separate LiveContainer guest or a separately signed install. Do not replace an existing guest or copy full containers blindly. No migration operation is included in this fork.

Upstream notices remain, including the About attribution “Includes work from BCD by thebcd69 (https://github.com/thebcd69/bcd-games)”. Changed BCD files are marked modified; original notices are retained. The implementation references the user's BLACK screenshot for hierarchy, the cited OpenMW/Serious Sam touch paths for independent ownership, and Valve's Mouse Joystick concept. No game assets or code from those ports were copied.

## Input path

Stock controls retain `TouchControlsOverlay → BCDTouchLive → TouchPadSurface → GamepadInput.touch → TouchGamepadState → winios_gamepad_set_state`. Physical arbitration and gyro code remain in GamepadInput. Relative mouse aim remains in the stock input profiles (`BCDAimZone`, `BCDTouchExtrasLive`). Stock radial/gesture actions still dispatch through `BCDInputActionRunner`; they are disabled while a pack owns gameplay.

Validated packs use `BCDInputLive.refresh → BCDPackStore.activate → BCDPackLayer/BCDControlPackSurface`. A single UIKit surface assigns movement, look, button, drag-fire, radial, gesture or editor roles at touch-down. Finger identity survives crossing controls. Each hold has its own UUID; releasing duplicate fire cannot cancel another finger. Radial selection holds its own output until release for hold actions; tap/release actions pulse only on release. Gesture recognition has a dedicated start region.

The overlay's ControlsWindow gives the full active pack surface its direct touches, bypassing the stock button-geometry filter. TouchMouseGate suppresses legacy mouse fallback while a pack owns input, including when an older always-mouse override is set. Physical pointer events retain their route to the game; stock hit testing returns when the pack is disabled.

Timestamped look displacement becomes velocity in `BCDMouseJoystick`, not a vector from the initial landing point. Output saturates with no backlog and expires on GamepadInput's 4 ms sampler even without a physical controller. Lift, cancellation, pause, focus loss and profile changes clear aim. Pack movement, buttons and look merge into XInput slot 0. A controller pack forces XInput mode for that session; stock physical/HID settings remain available outside it. `BCD_TOUCH_TRACE=1` enables host publish lines for diagnosis. These are **host publishes**, not guest evidence.

Game Options → Game touch pack prepares existing installs. The pack toolbar exposes explicit contexts, editor, actual hit regions, stock controls for the session and reset. In the editor, controls can move, resize and change opacity; hold buttons can gain drag aim and an optional left duplicate. The inspector exposes binding labels, sensitivity, vertical scale, inversion and dead-zone compensation. Invalid edits that cover the reserved rectangle are rejected. Overrides are stored by stable game identity separately from generated bindings and survive regeneration when the action/control can still be matched.

Game Options also saves **Use generated controls next launch** or **Use stock input profile next launch** per game. The stock choice retains that profile's relative-mouse aim option. Switching input identities waits for a new launch; the existing toolbar's stock-for-this-session action remains available.

## Build and checks

Use a Mac with an iOS 26 SDK or the fork's manual Actions workflow. Windows cannot link this iOS app. Source changes and desktop-worker checks need only the top-level checkout; CI retrieves the engine dependencies.

The engine submodule pins are unchanged:

| Submodule | Commit |
|---|---|
| FEX | `959ac0616918ae1afe98f57d5daaabb07bb196f0` |
| Wine | `469e08af66c2638b74422e3d068620d400272d55` |
| DXMT | `8ae252b401bdee3ba725e391fba24dc2792f21af` |
| Madeira Dock | `72558e416a390f3669457930f09a389e54f49556` |

```powershell
gh workflow run touch-checks.yml --repo arjunkl/bcd-touch --ref wo-bcd-touch-001
gh workflow run touch-preview.yml --repo arjunkl/bcd-touch --ref wo-bcd-touch-001
gh workflow run touch-guest.yml --repo arjunkl/bcd-touch --ref wo-bcd-touch-001
gh workflow run touch-ipa.yml --repo arjunkl/bcd-touch --ref wo-bcd-touch-001
```

`touch-ipa.yml` derives the dependency/build phases from upstream's v0.1.626 workflow. It does not use upstream OTA credentials or publish signed releases. It archives Debug, preserving upstream's game-running configuration, and uploads `BCD-Touch-Lab-unsigned.ipa` only after successful archive. Native Wine targets are corrected to the targets actually emitted by the pinned `tools/makedep.c`: `__tooldeps__` and `include/all`. Full upstream tests are not run by this reduced archive job; targeted checks run in a separate workflow.

The upstream Git tree also omits the converter dylib expected by `build/madeira-d3d12/deps.sh`. CI runs `python3 tools/touch-packs/stage-converter.py` to recover only that dependency from the hash-pinned v0.1.626 release. The release-file digest differs from the recorded source-file digest; staging writes an explicit per-file pin into the CI working copy of deps.sh and records both digests and the verified archive digest in `converter-provenance.json`, also bundled beside the converter. It does not claim the files are byte-identical. It does not install the stock IPA or reuse its app executable. The archive remains a fresh build of the fork.

The cold extra-Wine-DLL build also left four required opt-in files missing. `stage-base-runtime.py` recovers only missing unchanged runtime DLLs from that same verified release, records per-file hashes and retains existing source outputs. Upstream kernelbase/setupapi marker/export verifiers and the full opt-in packaging check still run. A separate `touch-base-check.yml` preflight verifies recovery without compiling the engine. Package provenance distinguishes these base runtime dependencies from the freshly compiled fork application.

After dependencies and staged notices are built by that workflow, the archive command is:

```sh
xcodebuild -project app/Madeira.xcodeproj -scheme Madeira -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO archive -archivePath build-out/Madeira.xcarchive
```

The schema/worker command and preparation instructions are in [tools/touch-packs/README.md](tools/touch-packs/README.md). Pilot packs are under `packs/pilots`; their identities contain recorded metadata and an explicit unreported build where unavailable. They must match the actual installation identity before caching/application; the worker generates for the current identity. Do not bypass that match to force a sample pack onto a different build.

## Pilot and physical receipt

Dread Delusion and Chronicles of the Wolf were confirmed by the user to run on the iPhone. That confirmation predates this fork. Dread's controller pack includes five dated developer-documented defaults (equipment, map and next weapon/item/spell); attack/interact/jump/block remain raw or unresolved. Installed-build freshness and player remaps still need confirmation. Chronicles' keyboard pack derives named actions from the observed player config; its controller mapping remains unresolved. Neither pack is physically tested.

Pending on iPhone: installation/JIT launch; current game bindings and camera options; strafe+hold fire+fine correction; lift/reland/long sweep; button-crossing; left fire; hold-and-drag; cancellation; menu/focus transitions; gyro and physical controller regression; launch persistence; latency and feel. Record the game's horizontal/vertical controller sensitivity, acceleration, dead zone and inversion alongside pack calibration. Do not infer a comfort verdict from the host timing tests.

Pending guest evidence: run the compiled `bcd-touch-input-trace-x64.exe` from the guest-diagnostic artifact. Start/Menu arms recording. Exercise the touch pack, radial and gestures without touching keyboard/mouse. `touch-input-trace.jsonl` records XInput slot 0 and legacy/raw keyboard/mouse counters. This tool generates no input. It has not yet been run in Wine on the phone, and no zero-keyboard/mouse guest result is claimed.

Simulator images use the production UIKit renderer with engine stubs and an explicitly labelled empty backdrop. They establish visible controls and hit geometry, not gameplay, iPhone feel, actual game HUD clearance or guest delivery. BLACK comparison remains a visual design assessment until the same in-game view can be captured physically.
