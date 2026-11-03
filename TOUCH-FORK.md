# WO-BCD-TOUCH-001 test fork

Base: BCD **v0.1.626**, `adc9cc742f52601a42f52ac6b4fbcc701bdb16ad`. The earlier local v0.1.623 checkout was clean and had no touch branch. Work continued in a separate checkout and the branch `wo-bcd-touch-001` at https://github.com/arjunkl/bcd-touch.

**Shared authoring IPA ready:** `BCD-Touch-controls-6c27cf8.ipa`, 185,690,749 bytes, SHA-256 `ade1826a5de6273982ac21d429690b5987b42a8f2c30312a3eab97e39a569bfa`. App source `6c27cf87eab5a3094c5f078b0a8bf6e91e3ad7f3`; [full build](https://github.com/arjunkl/bcd-touch/actions/runs/41604861178) and [native packages](https://github.com/arjunkl/bcd-touch/actions/runs/41614413524) passed. Exact-source SDK, 35-image simulator/store/restart tests and a genuine desktop version-2 Chronicles round trip passed. Five genre presets, the shared 44-icon/binding editor, version-2 keyboard/mouse inputs and durable personal edits are implemented. The updated worker runs separately on port 8939; the phone remains on df25bb3 and its existing endpoint until the new update is installed and verified. [Authoring workflow](CONTROL-AUTHORING.md), [delivery receipt](receipts/touch/authoring-20261103/delivery.json).

**Installed existing-slot IPA:** `BCD-Touch-aim-df25bb3.ipa`, 185,549,333 bytes, SHA-256 `b9f39cdf541185e8fb3150cbf8ac67cb75e55775315786c03bcdd02d4827200a`. App source `df25bb3f0bb7308b81a79adcd79f4242502e7ac4`. The [full build](https://github.com/arjunkl/bcd-touch/actions/runs/41491849116) and [native sideload packaging](https://github.com/arjunkl/bcd-touch/actions/runs/41500353783) passed. The package uses the existing BCD base bundle ID, requests the three sideload entitlements, and passed signature/instruction/CRC/SHA checks. [Package receipt](receipts/touch/aim-delivery-20261102/existing-update-package.json). The owner has signed and installed it in the existing slot. Source, effective increased-memory/debugging rights and scoped settings preservation were read back; the worker endpoint was corrected after the PC address changed. [Phone receipt](receipts/touch/aim-delivery-20261102/phone-installed.json). The owner now accepts core Dread swipe gameplay, with sensitivity slightly low; [scoped physical receipt](receipts/touch/aim-delivery-20261102/phone-playtest.json).

**Historical aim failure on the previous `033603f`:** Dread's WGI bridge restored movement and Attack, but even the reviewed 33-action pack produced tiny camera movements and missed swipes on that old binary. The new IPA contains the delivery-clock fix, with SDK, independent-frame-clock and production publisher fixtures passed. A FEX host-cache build failure was corrected before the successful archive. The owner's new-binary acceptance covers core Dread swipe gameplay; measured latency, guest traces and wider physical checks remain pending. [Timing/Valve comparison](MOUSE-JOYSTICK-NOTES.md), [test receipt](TEST-RECEIPT.md).

Historical previous installed build: **`BCD-Touch-fix-softlocks-033603f.ipa`**, an owner-authorized update for the existing BCD slot (`com.thebcd69.bcd`). Source `033603f365a7c9a69a7b1027e58edcb7c3acfd1b`, base `adc9cc742f52601a42f52ac6b4fbcc701bdb16ad`. [Full build](https://github.com/arjunkl/bcd-touch/actions/runs/41427627554) and [sideload packages](https://github.com/arjunkl/bcd-touch/actions/runs/41432302557) passed. Size 185,510,381 bytes; SHA-256 `80e7aa3fad0fdf3e61155488d1b71c3dbfd93d528256bb02bf891c4559609c5a`. It includes dialog touch passthrough, a fixed editor return header, floating movement, fresh touch-only focus and idempotent simultaneous input. This old IPA does not contain the new timing fix.

The new packaging run also provides **BCD-Touch-Lab-sideload** for a separate install; the owner's requested existing-slot artifact is **BCD-Touch-existing-update**. Both request the required entitlements and require personal signing. The local existing-slot delivery is `BCD-Touch-aim-df25bb3.ipa`.

The default separate app identity is `com.arjunkl.bcdtouch`, display name **BCD Touch Lab**, with an original teal touch/swipe icon and isolated `bcdtouchlab://` callback URLs. Helper extension IDs derive from that identity; MemoryHost has its own matching identifier. The initial separate package did not modify installed data. The owner later authorized the existing-slot update described below. A new identity does **not** automatically share BCD's data container: use a separate LiveContainer guest or a separately signed install. Do not replace an existing guest or copy full containers blindly. No migration operation is included in this fork.

The owner subsequently requested an **in-place update** after SideStore rejected a fourth active app. The optional `touch-sideload-packages.yml` workflow accepts an explicitly pinned source run, commit and SHA and repackages it as `BCD-Touch-update-existing-unsigned.ipa`, using the original base identity `com.thebcd69.bcd`, matching helper IDs, and both `bcd://` and `bcdtouchlab://` callbacks. SideStore applies the existing account suffix while signing. This variant replaces the BCD executable in its existing slot. Settings and preferences were backed up before preparation. The update is installed. Settings/controls/game folders and effective memory/debugging rights were checked after signing. The next aim binary must use this same slot; no app should be deactivated or removed.

Both sideload package variants reuse upstream `tools/ota-variants.py`'s `fakesign` function. Its ad-hoc signature requests increased memory, extended virtual addressing and debugging access, allowing SideStore to retain rights permitted by the existing profile. It contains no personal certificate or provisioning profile and still requires SideStore signing. The original raw unsigned archive lacked these requests, so use a **sideload package** with SideStore. Packaging verifies code signatures and unchanged executable instruction hashes; it does not rebuild the engine or certify device behavior.

The first c06 package passed [packaging run 41332474319](https://github.com/arjunkl/bcd-touch/actions/runs/41332474319), then failed the owner’s gameplay test. Its [historical package receipt](receipts/touch/existing-update-package.json) is retained for provenance. The current corrected delivery and artifact run are listed at the top.

Upstream notices remain, including the About attribution “Includes work from BCD by thebcd69 (https://github.com/thebcd69/bcd-games)”. Changed BCD files are marked modified; original notices are retained. The implementation references the user's BLACK screenshot for hierarchy, the cited OpenMW/Serious Sam touch paths for independent ownership, and Valve's Mouse Joystick concept. No game assets or code from those ports were copied.

## Input path

Stock controls retain `TouchControlsOverlay → BCDTouchLive → TouchPadSurface → GamepadInput.touch → TouchGamepadState → winios_gamepad_set_state`. Physical arbitration and gyro code remain in GamepadInput. Relative mouse aim remains in the stock input profiles (`BCDAimZone`, `BCDTouchExtrasLive`). Stock radial/gesture actions still dispatch through `BCDInputActionRunner`; they are disabled while a pack owns gameplay.

Validated packs use `BCDInputLive.refresh → BCDPackStore.activate → BCDPackLayer/BCDControlPackSurface`. A single UIKit surface assigns movement, look, button, drag-fire, radial, gesture or editor roles at touch-down. Finger identity survives crossing controls. Each hold has its own UUID; releasing duplicate fire cannot cancel another finger. Radial selection holds its own output until release for hold actions; tap/release actions pulse only on release. Gesture recognition has a dedicated start region.

The overlay's ControlsWindow gives the full active pack surface its direct touches, bypassing the stock button-geometry filter. TouchMouseGate suppresses legacy mouse fallback while a pack owns input, including when an older always-mouse override is set. Physical pointer events retain their route to the game; stock hit testing returns when the pack is disabled.

Timestamped look displacement becomes velocity in `BCDMouseJoystick`, not a vector from the initial landing point. Output saturates with no backlog and expires on GamepadInput's 4 ms sampler even without a physical controller. Lift, cancellation, pause, focus loss and profile changes clear aim. Pack movement, buttons and look merge into XInput slot 0. A controller pack forces XInput mode for that session; stock physical/HID settings remain available outside it. `BCD_TOUCH_TRACE=1` enables host publish lines for diagnosis. These are **host publishes**, not guest evidence.

Game Options → Game touch pack prepares existing installs. The pack toolbar exposes explicit contexts, editor, actual hit regions, stock controls for the session and reset. In the editor, controls can move, resize and change opacity; hold buttons can gain drag aim and an optional left duplicate. The inspector exposes binding labels, sensitivity, vertical scale, inversion and dead-zone compensation. In a running game, tap the blue hand icon → **Edit pack** → **Aim sensitivity** (0.1–8), then **Back to game**. Try 1.5 from Dread's initial 1.0. Changes apply when gameplay resumes and save automatically in that game's personal override; other games retain their own values. Regeneration preserves the override. Increasing this value reaches the game's stick turn-rate limit sooner; it cannot exceed that limit. Invalid edits that cover the reserved rectangle are rejected. Overrides are stored by stable game identity separately from generated bindings and survive regeneration when the action/control can still be matched.

Game Options also saves **Use generated controls next launch** or **Use stock input profile next launch** per game. The stock choice retains that profile's relative-mouse aim option. Switching input identities waits for a new launch; the existing toolbar's stock-for-this-session action remains available.

## Build and checks

The initial c06 unsigned test IPA was built successfully in [run 41325781697](https://github.com/arjunkl/bcd-touch/actions/runs/41325781697) from app source `c06c500614690f4e65fd935c54a3f9e1b793e39c`, with Xcode 26.3. Download the `BCD-Touch-Lab-build` artifact; it contains `BCD-Touch-Lab-unsigned.ipa` and build/provenance logs. The artifact expires after seven days. Signing, installation and physical testing remain separate steps.

The downloaded IPA passed the static checks in `tools/touch-packs/inspect-ipa.py`. Size: 185,213,699 bytes. SHA-256: `602bb64719babbb08e97dfe278cc2634b55eae5b89f2b02331d60fe8fa29f4ba`. See [package inspection](receipts/touch/ipa.json) and [test receipt](TEST-RECEIPT.md) for the exact evidence and pending device checks.

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

Dread Delusion and Chronicles of the Wolf were confirmed by the user to run on the iPhone. That confirmation predates this fork. Dread's current 33-action controller pack uses the installed game's serialized binding records, with explicit on-foot/menu/airship contexts; RT = Attack is also owner-confirmed. Current player remaps and in-game camera settings remain unverified. Chronicles' keyboard pack derives named actions from the observed player config; its controller mapping remains unresolved. The installed-identity Dread pack completed real phone generation/validation. Movement and Attack work after the WGI setting; the owner now accepts core swipe gameplay on the delivery-clock binary, with sensitivity tuning requested. Chronicles remains physically untested.

The owner accepts core swipe gameplay after the movement/held-Attack/fine-correction/long-swipe/thumb-rest protocol. Pending on the corrected iPhone build: per-game sensitivity tuning and persistence retest; dialog taps and visible editor escape; separate floating-base and full binding checks; current camera options; lift/reland; button-crossing; left fire; hold-and-drag; cancellation; menu/focus transitions; gyro and physical controller regression; launch persistence; measured latency and broader comfort checks. Record the game's horizontal/vertical controller sensitivity, acceleration, dead zone and inversion alongside pack calibration. Do not infer a comfort verdict from the host timing tests.

Pending guest evidence: run the compiled `bcd-touch-input-trace-x64.exe` from the guest-diagnostic artifact. Recorder v2 starts recording automatically, including disconnected slots; Start/Menu pauses or resumes recording and resets counters. Exercise the touch pack, radial and gestures without touching keyboard/mouse. `touch-input-trace.jsonl`, beside the EXE, records all four XInput slot result codes, state changes and one-second heartbeats with legacy/raw keyboard/mouse counters. This tool generates no input. It has not yet been run in Wine on the phone, and no zero-keyboard/mouse guest result is claimed.

Simulator images use the production UIKit renderer with engine stubs and an explicitly labelled empty backdrop. They establish visible controls and hit geometry, not gameplay, iPhone feel, actual game HUD clearance or guest delivery. BLACK comparison remains a visual design assessment until the same in-game view can be captured physically.


## Shared editor scope

The owner initially deferred richer authoring until core input worked. They now explicitly prioritize automatic preparation and manual customization equally. The source implementation and current build/test status are described in [Controls for another game](CONTROL-AUTHORING.md). The installed phone remains on the accepted df25bb3 timing build until the new authoring IPA is built, packaged and signed. Local SF Symbols form the current catalog; custom generated artwork, mixed-mode controller/mouse packs and automatic game-state detection are not implemented.


To reproduce the accepted df25bb3 timing package from its pinned source artifact (seven-day CI retention):

```powershell
gh workflow run touch-sideload-packages.yml --repo arjunkl/bcd-touch --ref wo-bcd-touch-001 -f source_run=41491849116 -f source_commit=df25bb3f0bb7308b81a79adcd79f4242502e7ac4 -f source_sha256=bc18a24bec8d73ee0041bc65d7f462e930026c458e3442ef27780acbb7f400f1
```

The fast SDK check also compiles the actual ControlsWindow and legacy TouchControlsHost attachment method, covering the integration gap exposed by the first revised archive. On macOS 26, ASan host checks use the installed current LLVM runtime; non-ASan checks and all iOS app/runtime compilation retain the selected Xcode toolchain. Test assertions and sanitizers remain enabled.
