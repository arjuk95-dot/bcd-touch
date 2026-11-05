# Noita cursor touch pack

This pack runs on the BCD 0.1.630 touch branch, using keyboard/mouse outputs. Its flat outline HUD follows the supplied gameplay/equipment references. It contains no recreated game scenery, native HUD, live item information or invented flask contents.

The left pad floats from each touch-down and disappears on release. A/D are digital movement, W levitates, and S activates only past the deeper Down/Eat threshold. Deadzones and hysteresis are configurable. There is no analog movement-speed claim.

The right area is a relative touchpad. Touch-down/lift emit no mouse motion; subsequent touches continue from Wine's cursor. Fractional deltas survive slow swipes. Sensitivity is linear, scaled using the presented Metal surface and live guest resolution. The existing Wine cursor reports drive the visible OS cursor when applicable; the profile never estimates/recenters its position. This preserves a screen position, not a world-space target when the camera scrolls.

Slide an aiming touch into the actual Fire circle to acquire left mouse. It remains held while dragging elsewhere until lift/cancellation. Starting directly on Fire presses at the existing cursor and allows dragging. Crossing other buttons never activates them. Independent movement/fire owners release independently. Fire/Use acts on the selected item; it is not guaranteed to be a wand or safe to use.

Equipment has eight stable, numbered sectors: wand slots 1–4, item slots 5–8. Hold/slide/release selects through a direct number key; release in the centre cancels. A quick tap leaves the wheel open for tap selection or More. Opening it cancels aiming/fire and quarantines that finger until lift; an already-held movement touch continues. Equipping requires a fresh firing gesture. The wheel and More do not pause Noita.

More provides deliberate Throw, held Down/Eat, pointer mode, customization and return. Throw is separate from Fire. The editor can expose optional direct Throw/Levitate/Down buttons. Inventory sends Tab after releasing gameplay inputs, then enters explicit pointer mode with Select/Drag and Secondary Click. Close Inventory sends Tab; Resume sends Escape in pause mode. Gameplay Only and Pointer Mode Only recover from an external input/dialog desynchronizing the overlay. These switches do not prove the game's actual state. Focus loss/backgrounding/rotation clear held inputs; the explicit UI mode survives overlay recreation during the same session.

Customization uses the shared editor, including full-screen movement/overlap, sizes, opacity, optional labels, bindings, activation regions, movement thresholds, cursor/firing sensitivity, radial position/size, export/import and reset. Personal overrides survive regeneration. The equipment panel hides inactive gameplay buttons so they do not obstruct sectors. More leads to the editor; the extra hand menu is omitted for this cursor HUD. The normal BCD session menu remains available.

Virtual XInput/HID output is suppressed for this cursor-pack session, including attached pads, to prevent switching back into controller input. Choosing another/stock profile restores the normal pad path at the next launch. No Noita setting or save is changed. Cursor gyro is not exposed because this pack has no verified cursor-gyro backend.

## Binding evidence and status

The current exported pack uses the owner's **expected** KB/M defaults: A/D, W, S, left/right mouse, F, E, Tab, 1–8 and Escape. Installed bindings and Noita's controller-detection setting have **not yet been verified**: the paired iPhone terminates Wi-Fi file access before those files can be read. The app now reads only bounded input attributes from known `users/*/AppData/LocalLow/Nolla_Games_Noita/save_shared/config.xml` paths, includes their digest in the identity, and attaches available attributes to exported evidence. Unrecognized attributes are not guessed mappings. Confirm remaps in Noita before marking the pack physically tested.

The data-only format is version 4. Optional `digitalMovement` and `cursorControls` capabilities leave versions 1–3 on their previous paths. Both Swift and the desktop validator enforce the contract. Runtime modes are explicit and transient; no scripts or game-state inference are embedded in packs.

## Build and install

Use the existing `touch-ipa.yml` workflow on `wo-bcd-touch-001-v630`, `macos-15-intel` with selected Xcode 26.3. After the archive passes, package it with `touch-sideload-packages.yml` using the exact full-build run, embedded source commit and raw IPA SHA-256. Use its **existing-update** artifact with the same SideStore account to update the installed BCD slot.

After installation, open Noita's Game Touch Pack page and choose Prepare Controls, then generated controls for the next launch. This selects the built-in Noita KB/M preset using the current installation identity. Start Noita with JIT as usual. Existing selected local profiles remain selected until this preparation action. Export Controls produces the current per-game identity and personal edits; importing a pack from another identity is deliberately rejected.

## Verification

Focused production-engine tests cover cursor continuity/stationary/retouch, direct/slide fire, independent owners, movement/flight/deep-down thresholds, unrelated boundary crossing, radial cancel/select/fire quarantine, explicit pointer dragging, pause/focus-style cancellation, 60/120 Hz fractional motion and render scales. Slot pulses are checked against representative 30/60 FPS sampling clocks. UIKit fixtures exercise actual routing, rendering and release observers. The publisher fixture separately checks cursor-only XInput/HID isolation and retained controller-pack behavior.

Simulator exports are implementation UI on blank backgrounds, clearly labelled **no game**. iPad images use offscreen iPad geometry in an iPhone simulator. They are not screenshots of Noita gameplay or a physical iPad. Guest/SDL cursor delivery, camera-scrolling behavior, single shots, sustained fire, equipment safety, inventory dragging, signing/JIT and physical feel still need on-device testing.
