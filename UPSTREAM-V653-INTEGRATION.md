# BCD 0.1.653 touch integration

Status: integration candidate awaiting CI and phone validation. Repository write access has been restored. Publication and native build checks are proceeding; no installable v653 package or device result is claimed yet.

## Bases and decisions

- Fork baseline: `733333d1d822b2e46798ce54021711d52c27add9`, branch `wo-bcd-noita-workshop-001`.
- Upstream: tag `v0.1.653` (`c3c2d15`), released 11 November 2026.
- Candidate branch: `wo-bcd-upstream-653-001`. Original branches are unchanged.
- Adopt upstream's GL runtime, Wine/FEX pins, source-built Mesa/MoltenVK recipes and matching PE build steps together. Do not apply the old fork `prepare-wine.py` patch or reuse the old GL dependency artifact with these pins.
- Keep the fork's floating movement, timestamped swipe aim, game-specific packs, Noita keyboard/mouse controls, aimed surface taps, personal edits and Dock cursor reporting. The 17 core control/pack files listed in the validation receipt are byte-identical to the fork baseline. Integration routing files necessarily differ.
- Use the upstream present counter everywhere. It already includes GL presents, so no separate additive counter is used.
- Keep existing application data and control associations. A game with associated touch-pack state cannot be moved between storage locations until path-key migration is implemented and tested. This guard runs before copy/delete; stock games without related state remain movable.

## Noita

Upstream now supplies recommended Noita settings and a diagnostic-driven `env.MADEIRA_WOW_RWX_PLAIN = 1` auto-tune candidate for a LuaJIT code-area failure. It is explicitly unproven. This source merge does not establish that Continue or gameplay is fixed. It does not reset existing game settings, overwrite personal packs, or force this experimental key into the user's existing profile.

## Validation

The receipt in `receipts/touch/upstream-v653/` distinguishes host checks, skipped Swift/SDK execution and physical tests. Passed local checks include synthetic cursor/window coordinates, bounded x86 failure diagnostics, GL routing/present counting and source UI checks, architecture metadata, worker/schema/state validation, project source registration and move-safety wiring.

No Swift compiler, macOS SDK, iOS SDK, device or running Windows guest was available in the local executor. SDK compilation, simulator previews, publisher tests, complete native archive and sideload packaging are pending. No device installation, JIT, gameplay, frame rate, thermal or data-preservation result is claimed.

Four small reference documents were reconstructed from public code/notices because the upstream public Git tree and exact release source archive omit them while the checks require them. Each document labels that provenance; none claims to reproduce unavailable upstream prose or device evidence.

## Build and package

Publish this candidate branch without changing the original development branches. `touch-ipa.yml` runs the complete v653 engine/build recipe on macOS, with the fork's pinned converter/runtime recovery, tested Intel LLVM selection and unchanged hash-verified 7-Zip programs. It runs the fork checks too, then packages an existing-slot update and verifies code signatures, entitlements, identities, source stamp and unchanged main/helper instruction sections.

The `BCD-Touch-existing-update` artifact is the intended phone deliverable. Do not offer the intermediate `BCD-Touch-Lab-build` IPA as an existing-slot update: it still has a separate laboratory identity.

The preview, production publisher, touch and OpenGL workflows must pass for the same commit before reporting a build ready for testing. Host and simulator checks are not game/device validation.

## Phone acceptance after a package exists

1. Save/close the current game. Keep the current BCD installation and a settings/save backup. Do not uninstall, deactivate, reset the library or reimport default packs over personal edits.
2. Sign the existing-slot IPA with the same SideStore account and update the current BCD slot. If it proposes a second app identity or replacing data, stop rather than deleting the original. Re-enable JIT normally.
3. Verify version/source and that games, saves, control layouts and personal edits remain present.
4. Test Dread Delusion movement/swipe aim and a known Direct3D game first, including simultaneous movement/attack and returning from the menu/background.
5. In Tenebris Somnia, toggle Aim and tap the gameplay surface. One tap should attack once; drags, holds, movement, editor/menu touches and Aim-off taps must not attack.
6. Test Noita on Wi-Fi with Desktop OpenGL (Zink): menu/cursor, Continue, movement/flight, aiming/casting and inventory. If Continue crashes, export that session log with the build/source and exact point of failure. Do not treat a new workaround as a confirmed fix or change several tuning variables together.

If a regression occurs, retain the log and restore a previously verified package using the same app identity/signing account, without uninstalling. Physical rollback and data preservation still require verification.
