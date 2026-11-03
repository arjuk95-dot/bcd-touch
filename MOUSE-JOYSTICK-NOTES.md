# Mouse Joystick implementation and current limits

The owner's 3 November phone retest accepts core Dread swipe gameplay on installed source `df25bb3`, following the movement/held-Attack/fine-correction/long-swipe/thumb-rest protocol. Sensitivity feels slightly low. The previous `033603f` aim failure remains recorded below. This qualitative physical acceptance is distinct from measured latency, guest traces and the wider regression matrix. [Physical receipt](receipts/touch/aim-delivery-20261102/phone-playtest.json).

## What Valve documents

Valve's [Input Source Modes: Mouse Joystick](https://partner.steamgames.com/doc/features/steam_controller/input_source_modes?l=english) describes mouse-like motion expressed as joystick output for games that reject mixed mouse/controller input. Its settings include minimum horizontal/vertical output, vertical scaling and inversion. Valve recommends raising the game's own controller camera sensitivity to make the most of its turn rate. Trackball momentum and edge spin are optional features; this fork's preset has neither.

That page documents behavior and configuration, not an implementation algorithm or source code. This fork uses its own velocity conversion; it is not an exact Steam Input clone. It currently exposes shared radial dead-zone compensation plus vertical scaling, rather than Valve's separate per-axis minimum-output knobs. The game's own acceleration curve and maximum turn speed still constrain the result. The player's current in-game camera settings have not been recorded.

## Timing defect reproduced in our path

`UITouch.timestamp` measures when a sample was acquired. UIKit can deliver it later, including a batch of coalesced samples. The old publisher expired output relative to that source timestamp and derived expiry from historical subsample spacing. A 40 ms-old event could therefore expire before publication; replaying a coalesced batch could also make the deadline much shorter than the interval between real deliveries.

Code `d2433a8` uses source deltas for velocity and main-actor delivery uptime for expiry. The delivery time is captured before the serial queue hop; queue execution cannot renew an old packet. Each delivery publishes one displacement ending at the newest coalesced sample. A 4 ms sampling clock neutralizes output without more touch events. Delivery-adaptive expiry is bounded at 12–42 ms. The original delivery-aligned fixture observes neutral within 44 ms; an independently phased 4 ms publisher permits a bound of 46 ms, with up to one game frame before consumption. These are synthetic bounds, not measured wall-clock guarantees. Lift, cancel, focus loss, pause and profile change clear input immediately. No excess motion is queued after saturation.

[SDK tests](https://github.com/arjunkl/bcd-touch/actions/runs/41467076163) cover source 60/120 Hz, delivery 30/60/120 Hz, delayed events, unrelated clock origins, reversals and stale queued packets, with computed frame bounds at 30/60 FPS. The [extended independent-clock test](https://github.com/arjunkl/bcd-touch/actions/runs/41479598119) also passed: it samples published snapshots at independently phased 30/60 FPS game clocks and checks continuous motion and later neutral consumption. The [production publisher test](https://github.com/arjunkl/bcd-touch/actions/runs/41467079125) observes simultaneous slot-0 LS/RT/RS from a 40 ms-old event and later neutral aim while movement/fire remain held. These use synthetic timestamps and an engine spy; no guest or physical camera measurement is claimed. Isolated pulses can still fall between a game's polls, and the game may apply additional filtering.

Observed worst cases across the fixture's phases, measured **after the last delivery** (not after physical finger motion), are below. The simulated source events were delivered 40 ms late. Frame columns show consumption of the published state; they are not measurements of Dread's camera. [Full metrics](receipts/touch/aim-delivery-20261102/timing-independent-clocks.json).

| Delivery rate | Neutral published | Observed at 30 FPS | Observed at 60 FPS |
|---|---:|---:|---:|
| 30 Hz | 45.33 ms | 75.00 ms | 58.33 ms |
| 60 Hz | 27.67 ms | 58.33 ms | 41.67 ms |
| 120 Hz | 18.33 ms | 50.00 ms | 33.33 ms |

## Dread's binding evidence

The bounded installed-asset inspection found `Look` bound to a gamepad right stick with `StickDeadzone(min=0.2),ScaleVector2(x=50,y=40)`, and also to `<Pointer>/delta` in the keyboard/mouse binding set. Reviewed controller defaults and source offsets are in [the installed binding table](tools/touch-packs/references/steam-1574240-installed.json). Active remaps were not established. Unity documents that [control and binding processors can both apply](https://docs.unity3d.com/Packages/com.unity.inputsystem@1.4/manual/ActionBindings.html); the stacked-dead-zone fixture assumes standard control defaults, not confirmed custom game settings.

The applied controller pack uses sensitivity 1, vertical 1.25, inversion off, compensation .30 and full-stick velocity 600 UIKit points/s. The player still rejected aim after this data update on `033603f`. The delivery-clock binary `df25bb3` subsequently passed the owner's core swipe playtest. The installed editor already provides **blue hand → Edit pack → Aim sensitivity** (0.1–8), automatically saved per game and preserved through regeneration. A first trial of 1.5 is suggested; no calibration was changed remotely. Higher sensitivity reaches saturation sooner, within the game's own turn-rate limit. The owner's final calibration and in-game camera settings remain unrecorded.

## Native mouse-look alternative

BCD already has a relative-mouse bridge: `BCDAimZone`/`BCDTouchExtrasLive` send motion through `HardwareInput.postRelative` to `winios_pointer`. For a game accepting mouse input alongside controller input, this can bypass its stick dead zone and joystick turn curve. Dread's pointer binding makes this a plausible test, but simultaneous device-scheme acceptance remains unverified. An active full-surface controller pack currently captures those touches, so placing the stock mouse zone behind it does not make a working mixed mode.

A future explicit relative-mouse or mixed-mode choice must preserve touch ownership and mode validation, and must label its mouse output honestly. It must not silently add mouse events to a controller-only pack. Injecting camera state directly would require game/build-specific integration; the existing relative-input path should be tested first. No game camera hook or mixed-mode pack has been implemented in this timing change.
