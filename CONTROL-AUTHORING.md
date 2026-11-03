# Controls for another game

This phase shares one editor between researched game packs and offline genre presets. Exact-source SDK checks, simulator/store/restart fixtures, the full archive and native sideload packaging pass. The verified existing-slot IPA is `BCD-Touch-controls-6c27cf8.ipa` (185,690,749 bytes, SHA-256 `ade1826a5de6273982ac21d429690b5987b42a8f2c30312a3eab97e39a569bfa`). This authoring phase is not installed on the owner's phone yet. The accepted Dread timing build remains `df25bb3`; raising Dread's own look sensitivity improved camera speed. The editor's renamed **Swipe response** scales how fast finger motion reaches full right-stick output. It cannot raise the game's maximum turn rate.

## On the phone

Open the game's **Options → Game touch pack**. Choose a genre and input mode, then use either path:

- **Prepare researched controls** asks the configured desktop worker to identify bindings from supplied files/remaps and primary documentation. **Regenerate (keep personal edits)** applies changed genre/mode preferences to an existing cached result. Select **Use generated controls next launch** to leave a manual preset and return to the researched pack.
- **Start customizable offline preset** selects a local template for the next launch. Templates work without a worker. They expose raw Xbox outputs or conventional keyboard/mouse inputs with honest labels; a genre preset does not establish that game's actual bindings. Verify them in the game's controls screen. The researched pack and its edits remain separate.

During the game, **blue hand → Edit pack** opens the common editor. Add a button, select an action, give it a label and icon, choose the input it sends and its tap/hold/release behavior, then **Save action**. Controller packs offer Xbox outputs. Keyboard/mouse packs offer named keys, Ctrl/Shift/Alt chords, left/right/middle click and wheel actions. Advanced virtual-key chords use `keys:17+67` for Ctrl+C; at most four distinct keys in the Windows virtual-key range 1–255. Wheel actions tap or release; they cannot be held. Changing the pack's input mode takes a preset/preparation choice and a new launch.

The generator preserves valid per-game hit geometry instead of flattening all shooters into fixed slots. Generated candidates with intersecting same-context button/radial/gesture hit circles are rejected for repair; movement start regions are handled separately. A generated left-fire duplicate remains press-only so it cannot claim the right thumb's look owner. These are generation quality checks; personal editor layouts remain explicit player choices.

The icon catalog contains local system symbols for attacks, shooting, block, use, inventory, movement, spells, vehicles, menus and other common actions. It does not download executable artwork or claim these are custom generated illustrations. Icons, labels, input assignments and context membership are editable. Contexts switch explicitly through the toolbar; no on-foot/vehicle/menu state is inferred.

Controls retain move, size, opacity, left-duplicate and drag-aim editing. The radial can contain up to eight actions. New buttons are placed outside the reserved swipe rectangle in both device layouts; invalid edits show an error and leave the current controls active. **Undo** restores recent edits. **Back to game** stays outside the scrolling inspector. **Reset** restores the selected base preset; it can be undone during that session.

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

The LAN worker command and pairing configuration are in [the worker README](tools/touch-packs/README.md). On this PC, the updated worker is already running on port 8939 with a separate validated cache, using the existing private pairing token. The original port-8937 service is retained. The phone endpoint will switch after installation and source verification; the current phone configuration is unchanged. Credentials remain on the desktop. Generation, validation and physical testing remain separate statuses. Controller packs reject keyboard/mouse output, including gestures and radial selections. Pack version 2 adds key chords, middle click and wheel actions; existing version 1 packs remain supported. Older clients reject version 2 and keep their fallback.

After restarting this PC, the matching worker command is below. It is already running during this session; do not start a duplicate listener.

```powershell
python tools/touch-packs/worker.py serve --host 0.0.0.0 --port 8939 --state C:/Users/arjun/.codex/bcd-touch-worker-v2-state --token-file C:/Users/arjun/.codex/bcd-touch-worker-token.txt
```

## Verification scope

Required checks cover ten unknown-game templates (five genres, two modes), v1 compatibility, malformed/mixed-mode bindings, semantic edits through regeneration/restart, preset separation, shared-modifier ownership, middle-click cancellation, single wheel notches and existing controller-only touch routing. Desktop/SDK/simulator results are fixtures. Actual game compatibility, phone comfort, Files presentation and iPad operation still require physical testing of the new build.
