# Controls for another game

The free-placement and Tenebris version-3 extension passes SDK checks and 45 simulator renderer/store/restart exports at app source `b78e96073e65e6d1431376f5134ae08ea60dc037`. The full [iOS build](https://github.com/arjunkl/bcd-touch/actions/runs/41693381721) is running. The existing installed baseline below remains usable; the new behavior has not been physically tested.

The earlier authoring phase shares one editor between researched game packs and offline genre presets. Exact-source SDK checks, simulator/store/restart fixtures, the full archive and native sideload packaging pass. The verified existing-slot IPA is `BCD-Touch-controls-6c27cf8.ipa` (185,690,749 bytes, SHA-256 `ade1826a5de6273982ac21d429690b5987b42a8f2c30312a3eab97e39a569bfa`). The authoring update is installed: USB lookup verified the exact app source after the phone downloaded the IPA over Wi-Fi. Increased-memory and debugging rights were reported; extended virtual addressing was not reported. The earlier Dread timing build `df25bb3` was physically accepted; raising Dread's own look sensitivity improved camera speed. The editor's renamed **Swipe response** scales how fast finger motion reaches full right-stick output. It cannot raise the game's maximum turn rate.

## On the phone

Open the game's **Options → Game touch pack**. Choose a genre and input mode, then use either path:

- **Prepare researched controls** asks the configured desktop worker to identify bindings from supplied files/remaps and primary documentation. **Regenerate (keep personal edits)** applies changed genre/mode preferences to an existing cached result. Select **Use generated controls next launch** to leave a manual preset and return to the researched pack.
- **Start customizable offline preset** selects a local template for the next launch. Templates work without a worker. They expose raw Xbox outputs or conventional keyboard/mouse inputs with honest labels; a genre preset does not establish that game's actual bindings. Verify them in the game's controls screen. The researched pack and its edits remain separate.

During the game, **blue hand → Edit pack** opens the common editor. **Add button** lists every supported input, including LT and RT even when the base preset omitted them. It selects the new control and collapses the inspector for placement. Give the selected action a label and icon, choose its input and tap/hold/release behavior, then **Save action**. Version 3 also supports explicit toggle buttons. Controller packs offer Xbox outputs. Keyboard/mouse packs offer named keys, Ctrl/Shift/Alt chords, left/right/middle click and wheel actions. Advanced virtual-key chords use `keys:17+67` for Ctrl+C; at most four distinct keys in the Windows virtual-key range 1–255. Wheel actions tap or release; they cannot be held. Changing the pack's input mode takes a preset/preparation choice and a new launch.

The generator preserves valid per-game hit geometry instead of flattening all shooters into fixed slots. Generated candidates with intersecting same-context button/radial/gesture hit circles are rejected for repair; movement start regions are handled separately. A generated left-fire duplicate remains press-only so it cannot claim the right thumb's look owner. These are generation quality checks; personal editor layouts remain explicit player choices.

The icon catalog contains 44 local system symbols and four original flat outline drawings for sword attack, interaction, inventory and running. Other system icons cover shooting, block, movement, spells, vehicles, menus and common actions. It does not download executable artwork or claim these are custom generated illustrations. Icons, labels, input assignments and context membership are editable. Contexts switch explicitly through the toolbar; no on-foot/vehicle/menu state is inferred.

Controls retain move, size, opacity, left-duplicate and drag-aim editing. The radial can contain up to eight actions. The placement update allows personal controls to overlap the reserved swipe rectangle, other controls and the safe-area margins. **Move buttons** collapses the inspector to a compact toolbar; its arrow moves the toolbar between top and bottom. Dragging previews the position continuously and saves on release. Control centres can reach every display edge; clipping at an edge is the player’s choice. **Bring to front** selects which overlapping button receives a new touch. A touch already assigned to look, fire, movement or radial keeps its role until release. New buttons prefer a free slot but can still be added when those suggestions are occupied. Structural errors still leave the current controls active. **Undo** restores recent edits. **Back to game** stays outside the scrolling inspector. **Reset** restores the selected base preset; it can be undone during that session.

**Export controls** writes data-only JSON through Files. **Import controls for this game** validates the version, exact game/build/binding identity, current input mode, references, hit regions and size before applying anything. Exported packs contain binding evidence, not worker credentials. A different game's pack must not be imported as if its bindings matched.

If a controller pack is visible but its buttons do not respond, **Touch controller compatibility** exposes the same Xbox slot through Windows.Gaming.Input. This is the existing per-game bridge that restored Dread's input. Restart after changing it; turn it off if the game lists duplicate pads. Presets do not enable it globally or alter other games' configuration.

## Personal edits

Versioned personal edits are written atomically to `TouchPacks/personal-edits-v2.json`, with the base used for the edit. On regeneration, a three-way merge preserves fields the player changed while taking updated generated defaults for untouched fields. Personal action additions, removals, labels, icons, bindings, contexts, radial choices and aim calibration participate. If the merged result is invalid, the validated base remains active and the stored edit is retained for review.

Older `overrides.json` files remain readable and are left intact. Legacy edits keep their existing layout/aim semantics until saved by the new editor. A manual preset's edits have a separate key from that game's researched pack. This avoids replacing a working customized pack when experimenting with another genre or input mode.

## Desktop workflow for any title

The iPhone constructs requests automatically. For a desktop-authored request, no title-specific source-code change is needed:

```powershell
python tools/touch-packs/request-game.py --title "Game title" --store-id steam:12345 --executable "Games/Game/game.exe" --genre third-person --mode controller --output touch-evidence/game-request.json
python tools/touch-packs/worker.py generate touch-evidence/game-request.json --state C:/Users/arjun/.codex/game-pack-generation
```

Use `--regenerate` on the worker command to replace an existing cached result after changing preparation preferences. Use the actual store ID or `local`, actual executable and known edition/build. Add `--bindings PATH` for each selected text input configuration (32 KiB per file, 48 KiB total). This tool reads those files without editing them. It sends file names and contents, not account/registry directories. Request identity includes their digest. To apply through the app, use the app's own install request identity; a manually guessed executable/build may not match it.

The LAN worker command and pairing configuration are in [the worker README](tools/touch-packs/README.md). On this PC, the updated worker is already running on port 8939 with a separate validated cache, using the existing private pairing token. The original port-8937 service is retained. The owner requested USB setup after Wi-Fi app access failed. The phone endpoint now points to port 8939: the URL was changed after a small settings backup and verified by USB readback, preserving the token and every other configuration key. All 14 other backed-up metadata files remained byte-for-byte unchanged. No manual Files replacement is needed. Credentials remain on the desktop. Generation, validation and physical testing remain separate statuses. Controller packs reject keyboard/mouse output, including gestures and radial selections. Pack version 2 adds key chords, middle click and wheel actions. Version 3 adds explicit toggles, a configured toggle-to-tap slide, movement regions, no-look packs and original outline icons. Versions 1 and 2 remain supported. A worker with a valid newer cached pack returns an upgrade-required response to an older client without replacing that cache. The client keeps its playable fallback; pending requests advertise the new protocol ceiling after an app upgrade without changing their generation identity.

After restarting this PC, the matching worker command is below. It is already running during this session; do not start a duplicate listener.

```powershell
python tools/touch-packs/worker.py serve --host 0.0.0.0 --port 8939 --state C:/Users/arjun/.codex/bcd-touch-worker-v2-state --token-file C:/Users/arjun/.codex/bcd-touch-worker-token.txt
```

## Verification scope

Required checks cover ten unknown-game templates (five genres, two modes), v1 compatibility, malformed/mixed-mode bindings, semantic edits through regeneration/restart, preset separation, shared-modifier ownership, middle-click cancellation, single wheel notches and existing controller-only touch routing. Desktop/SDK/simulator results are fixtures. Actual game compatibility, phone comfort, Files presentation and iPad operation still require physical testing of the new build.

## Personal placement format

The placement update keeps generated and personal validation separate. Generated packs still require safe-area anchors and a clear swipe rectangle. Personal save/import/export and override merging permit overlap. Version-2 controls may carry optional `coordinateSpace: "screen"`; their x/y fractions address the complete display bounds. Missing `coordinateSpace` preserves existing safe-area positions. Control sizes keep their existing safe-area short-side scale. Personal ordering, anchors and positions survive regeneration/restart. The desktop equivalent is `python tools/touch-packs/worker.py validate controls.json --personal`; default validation remains strict for generated packs. Identity, binding/mode, finite geometry, bounded file size and hit-region checks remain in both paths. The new placement binary is still being built and tested; the installed 6c27cf8 authoring build does not yet contain this change.

## Tenebris owner layout (version 3)

[packs/personal/tenebris-somnia-owner-iphone.json](packs/personal/tenebris-somnia-owner-iphone.json) follows the owner's mockup. The owner confirmed the selected preset: LT Aim, RT Attack, A Interact, X Run, B Inventory and Menu Pause. This is an owner-authored personal layout, not a generated or independently researched default. Its unresolved section records the unreported build and unverified remaining actions.

Menu and Inventory sit in the upper corners. Aim, sword Attack, Run and the larger hand Interact sit low on the right. The movement stick centres under the thumb in the left start region and disappears on lift. All pack movement sticks now hide their idle hint during gameplay; editing and debug views expose the region. The iPad has separate positions.

Tapping Aim holds LT and turns the outline amber; tapping again releases it. Sliding from Aim into Attack produces one RT tap per touch and keeps Aim enabled, including when Aim was already on. Moving away and back into Attack cannot repeat that touch's attack. A drag that misses Attack retains Aim. Cancellation, focus loss, context/profile changes, editing and Menu clear the latch. Ordinary swipes and other fingers keep their own input owners.

The data-only version-3 fields are `behavior: "toggle"`, control `slideToAction`, control `labelPlacement`, layout `movementRect` and pack `lookMode`. This title uses `lookMode: "none"`; empty space sends no right-stick or mouse output. Toggle-to-tap slide requires explicit owner requirements; generation must not infer it for other games. `movementRect` uses full-display fractions; controls use `coordinateSpace: "screen"` for this personal mockup. Label placement can be inside or below.

Validate this personal layout with:

```powershell
python tools/touch-packs/worker.py validate packs/personal/tenebris-somnia-owner-iphone.json --personal
```

The current installed 6c27cf8 app cannot load version 3. Keep this file out of its generated cache. After the new app is installed, it can be imported into a matching controller pack, or selected as a backed-up local preset for that exact installed identity. Local presets and their personal edits are separate from researched packs. A local preset's Reset restores its own base. Physical Tenebris validation of the new toggle/slide and layout is pending.
