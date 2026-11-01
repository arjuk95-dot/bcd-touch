# Touch-fork test receipt

Base: v0.1.626, `adc9cc742f52601a42f52ac6b4fbcc701bdb16ad`. App/worker build revisions are recorded separately in the CI receipts. Bundle: `com.arjunkl.bcdtouch`, **BCD Touch Lab**.

The final candidate archive is [41319510340](https://github.com/arjunkl/bcd-touch/actions/runs/41319510340), app source `c8634675d86e0b7c09f84665a5d73deeddd5b27d`, currently building. No IPA or installation result is claimed yet. Earlier build failures were corrected: the native Wine target is `__tooldeps__`/`include/all`, not `__tools__`; the upstream Git tree omits the converter dylib despite its notice saying it is tracked; and the exact release's converter digest differs from the recorded source-file digest. Staging now verifies the whole v0.1.626 IPA and explicitly pins its extracted converter, recording both digests in provenance. Run 41317538782 passed that recovery and saved the expensive i386 cache, then was intentionally cancelled to build the corrected aim/input-choice source. No Wine/FEX/DXMT submodule source was modified.

| Check | Result and boundary |
|---|---|
| Production aim math and touch state | Pass: simultaneous LS/RT/RS state, two independent fire owners, reversal after saturation, stale expiry, reset, pause rejection, physical-stick arbitration, and first fine correction after a long stationary gap. Host fixtures; no guest/game. |
| Actual input publisher | Pass in [41318954382](https://github.com/arjunkl/bcd-touch/actions/runs/41318954382): production GamepadInput.swift publishes slot-0 LS/RT/RS together, neutralizes stale aim while movement/fire stay held, preserves an independently held trigger and exposes the trigger to upstream gyro gating. Engine-spy iOS simulator fixture, not a Wine guest or physical controller. |
| iOS UIKit/SwiftUI pack surface | Pass: SDK typecheck and simulator compilation of production pack views with engine stubs. Full app archive remains separate. |
| Stock touch/physical merge regression | Pass: existing upstream host test. Actual physical controller hardware remains pending. |
| Schema and Swift/Python validation | Pass: version, identity/build, input-mode, hit-region and reference checks. Controller packs reject keyboard/mouse outputs. |
| Desktop generation round trip | Pass: real HTTP 202 → Codex → validated HTTP 200 for Dread Delusion and Chronicles. Callers were desktop fixtures using recorded metadata, not iPhone install events. |
| Live primary-source research | Pass: the final Dread generation recorded one completed web-search call and used five dated, reviewed developer defaults. Attack/interact/jump/block remain unresolved. |
| Swift/desktop identity parity | Pass: production Swift canonical JSON hashing inside iOS simulator equals both Python request keys; [41314038921](https://github.com/arjunkl/bcd-touch/actions/runs/41314038921). |
| Duplicate/cache | Pass: duplicate HTTP requests while generating stayed 202; cached requests returned 200. |
| Invalid generation | Rejected: actual malformed model output was retained only as a rejected candidate, never activated. Receipt distinguishes generated=true from validated=false. |
| Restart/overrides | Host fixtures pass: separate override persistence and stable IDs. Production Swift store also passed cached/duplicate preparation, invalid-cache rejection, actual loopback connection failure fallback, moved-control override after simulated cache regeneration and a fresh simulator app process restoring the cache/edit. [Client receipt](receipts/touch/previews/client-phase-1.txt), [restart receipt](receipts/touch/previews/client-phase-2.txt). Actual phone install completion and regeneration remain pending. |
| Failed-generation retry bounds | Host fixtures pass: invalid candidates cannot trigger new paid jobs through polling; transient failures have durable backoff and a failure limit; a second worker on an occupied port fails before replaying persisted jobs. |
| Guest diagnostic | Compiled x86-64 Windows executable, 98,304 bytes. SHA-256 `b5a891e66a106fa8604fa58a57577419f5c90f7c7b6d57a896bf65e4ef5be144`. Not run in the phone's Wine guest. |
| Phone/iPad HUD geometry | Eight production-renderer fixtures exported successfully. See [preview receipt](receipts/touch/previews/preview-receipt.json), [phone HUD](receipts/touch/previews/dread-delusion-phone-hud.png), [actual hit regions](receipts/touch/previews/dread-delusion-phone-hits.png) and [iPad geometry](receipts/touch/previews/dread-delusion-pad-hud.png). Inactive-context controls, radials and gestures disappear from both drawing and acquisition. |

The deterministic sampling test uses a 4 ms clock and simulates timestamped motion at 60/120 Hz. These are computed state-transition results, **not measured phone camera latency**:

| Input samples | Neutral after last motion | 30 FPS observation upper bound in fixture | 60 FPS observation upper bound in fixture |
|---|---:|---:|---:|
| 60 Hz | 28 ms | 61.33 ms | 44.67 ms |
| 120 Hz | 16 ms | 49.33 ms | 32.67 ms |

The game can impose dead zones, acceleration and a maximum turn rate. Initial calibration is sensitivity 1, vertical scale 1, inversion off, dead-zone compensation 0.18 and full-stick velocity 900 UIKit points/s. These values are provisional until matched to Dread's actual controller settings. A single very short joystick pulse can fall between game polls; no guest camera response or universal latency bound is claimed from this fixture.

The renderer fixtures ran on **iPhone 16 Pro Max simulator, iOS 18.5**. Phone geometry is 956×440 points with left/right 62 and bottom 21 point insets. iPad geometry is 1194×834 points with top 24 and bottom 20 point insets, rendered offscreen on that same simulator. No iPad was booted for these exports and no game was running. The files explicitly carry “SIMULATOR RENDERER FIXTURE · NO GAME”.

Compared with the supplied BLACK reference, the first-person layout preserves low left movement, a larger right primary, thin translucent outlines, peripheral occasional controls and a clear central/right swipe rectangle. Cyan debug circles use the actual acquisition radii; the green rectangle shows reserved continuous aim space. Game health/ammo clearance, sightline during combat and actual thumb reach require a physical capture of the game. Dread uses dated developer defaults for equipment, map and next weapon/item/spell, with raw labels for unverified controller meanings. Its RT action does not claim a verified attack binding. Chronicles uses the observed named key bindings and a direction/attack/jump layout, with occasional actions on a labelled radial.

Still pending on the iPhone: unsigned IPA installation/signing or LiveContainer import; successful fork JIT/game launch; current binding and camera-setting confirmation; strafe+held fire+fine correction+lift/reland+long sweep; crossing nearby controls; optional left fire; drag-fire independent release; cancellation, focus and menu transitions; guest keyboard/mouse counters remaining zero for controller-only controls including gestures/radial; measured stop latency; physical gyro/controller regression; actual cached-install event, offline fallback and invalid-response handling; regenerated personal edits and correct pack on next launch. Repeat layout/feel checks on the user's iPad. Every one of these remains **physically untested**.

Version 1 uses local SF Symbols and visible output-label fallback, not downloaded custom artwork. Broader verified installed-file adapters remain future work. Live primary-source lookup is available on the worker, but a search without reliable per-button evidence leaves those bindings unresolved. The generator cannot resolve a missing binding by inventing a gameplay label or a weapon slot.

No installed BCD, games, saves, provisioning profiles or JIT pairing were changed. A local recursive submodule checkout filled the Windows drive; only this task's newly downloaded dependency working trees were cleared with `git submodule deinit`. Local dependency downloads were stopped and builds moved to CI. Existing projects/backups were not deleted by this task.
