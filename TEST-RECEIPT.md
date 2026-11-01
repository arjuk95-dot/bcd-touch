# Touch-fork test receipt

Base: v0.1.626, `adc9cc742f52601a42f52ac6b4fbcc701bdb16ad`. App/worker build revisions are recorded separately in the CI receipts. Bundle: `com.arjunkl.bcdtouch`, **BCD Touch Lab**.

The full unsigned archive is still running in [run 41313095321](https://github.com/arjunkl/bcd-touch/actions/runs/41313095321). No IPA or installation result is claimed yet. The earlier native Wine failure (`make __tools__`: no rule) was corrected to the pinned source's `__tooldeps__` and `include/all` targets. No Wine/FEX/DXMT submodule source was modified.

| Check | Result and boundary |
|---|---|
| Production aim math and touch state | Pass: simultaneous LS/RT/RS state, two independent fire owners, reversal after saturation, stale expiry, reset, pause rejection, physical-stick arbitration. Host fixtures; no guest/game. |
| iOS UIKit/SwiftUI pack surface | Pass: SDK typecheck and simulator compilation of production pack views with engine stubs. Full app archive remains separate. |
| Stock touch/physical merge regression | Pass: existing upstream host test. Actual physical controller hardware remains pending. |
| Schema and Swift/Python validation | Pass: version, identity/build, input-mode, hit-region and reference checks. Controller packs reject keyboard/mouse outputs. |
| Desktop generation round trip | Pass: real HTTP 202 → Codex → validated HTTP 200 for Dread Delusion and Chronicles. Callers were desktop fixtures using recorded metadata, not iPhone install events. |
| Duplicate/cache | Pass: duplicate HTTP requests while generating stayed 202; cached requests returned 200. |
| Invalid generation | Rejected: actual malformed model output was retained only as a rejected candidate, never activated. Receipt distinguishes generated=true from validated=false. |
| Restart/overrides | Host fixtures pass: cached pack reload and separate override file preservation; stable semantic IDs retained across regenerated identifiers. Actual on-device regeneration after moving a control remains pending. |
| Guest diagnostic | Compiled x86-64 Windows executable, 98,304 bytes. SHA-256 `b5a891e66a106fa8604fa58a57577419f5c90f7c7b6d57a896bf65e4ef5be144`. Not run in the phone's Wine guest. |
| Phone/iPad HUD geometry | Eight production-renderer fixtures exported successfully. See [preview receipt](artifacts/landscape-fixtures/touch-simulator-previews/preview-receipt.json). |

The deterministic sampling test uses a 4 ms clock and simulates timestamped motion at 60/120 Hz. These are computed state-transition results, **not measured phone camera latency**:

| Input samples | Neutral after last motion | 30 FPS observation upper bound in fixture | 60 FPS observation upper bound in fixture |
|---|---:|---:|---:|
| 60 Hz | 28 ms | 61.33 ms | 44.67 ms |
| 120 Hz | 16 ms | 49.33 ms | 32.67 ms |

The game can impose dead zones, acceleration and a maximum turn rate. Initial calibration is sensitivity 1, vertical scale 1, inversion off, dead-zone compensation 0.18 and full-stick velocity 900 UIKit points/s. These values are provisional until matched to Dread's actual controller settings. A single very short joystick pulse can fall between game polls; no guest camera response or universal latency bound is claimed from this fixture.

The renderer fixtures ran on **iPhone 16 Pro Max simulator, iOS 18.5**. Phone geometry is 956×440 points with left/right 62 and bottom 21 point insets. iPad geometry is 1194×834 points with top 24 and bottom 20 point insets, rendered offscreen on that same simulator. No iPad was booted for these exports and no game was running. The files explicitly carry “SIMULATOR RENDERER FIXTURE · NO GAME”.

Compared with the supplied BLACK reference, the first-person layout preserves low left movement, a larger right primary, thin translucent outlines, peripheral occasional controls and a clear central/right swipe rectangle. Cyan debug circles use the actual acquisition radii; the green rectangle shows reserved continuous aim space. Game health/ammo clearance, sightline during combat and actual thumb reach require a physical capture of the game. Dread's controller meanings are unresolved, so the pack uses honest raw labels rather than unverified fire/grenade/weapon labels. Chronicles uses the observed named key bindings and a direction/attack/jump layout, with occasional actions on a labelled radial.

Still pending on the iPhone: unsigned IPA installation/signing or LiveContainer import; successful fork JIT/game launch; current binding and camera-setting confirmation; strafe+held fire+fine correction+lift/reland+long sweep; crossing nearby controls; optional left fire; drag-fire independent release; cancellation, focus and menu transitions; guest keyboard/mouse counters remaining zero for controller-only controls including gestures/radial; measured stop latency; physical gyro/controller regression; actual cached-install event, offline fallback and invalid-response handling; regenerated personal edits and correct pack on next launch. Repeat layout/feel checks on the user's iPad. Every one of these remains **physically untested**.

Version 1 uses local SF Symbols and visible output-label fallback, not downloaded custom artwork. Broader verified installed-file adapters remain future work. Live primary-source lookup is available on the worker, but a search without reliable per-button evidence leaves those bindings unresolved. The generator cannot resolve a missing binding by inventing a gameplay label or a weapon slot.

No installed BCD, games, saves, provisioning profiles or JIT pairing were changed. A local recursive submodule checkout filled the Windows drive; only this task's newly downloaded dependency working trees were cleared with `git submodule deinit`. Local dependency downloads were stopped and builds moved to CI. Existing projects/backups were not deleted by this task.
