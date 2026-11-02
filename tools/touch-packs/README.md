# Desktop control-pack worker

Python 3.11+, `pip install jsonschema==4.26.0`, and an authenticated Codex CLI are required. `codex login` stays on the desktop; no OpenAI credential is copied to iOS. The phone uses only a scoped worker pairing token. Codex is invoked with a read-only sandbox, medium reasoning, an explicit JSON output schema, an isolated temporary directory and no user MCP configuration. Supplied actual bindings take priority. When they are insufficient, the worker enables live web search and directs Codex to primary manuals, developer/publisher controls documentation and official store announcements. It prohibits shell commands and local-account/file access in that research task. Unknown bindings remain unresolved; enabling search does not establish a binding by itself. `--no-research` disables this lookup. Receipts distinguish enabled research from observed completed search calls. The CLI's live-search flag is documented in the [official command reference](https://learn.chatgpt.com/docs/developer-commands?surface=cli).

Create a random token in a **private directory outside this checkout**, for example:

```powershell
python -c "import secrets,pathlib; pathlib.Path('C:/Users/arjun/.codex/bcd-touch-worker-token.txt').write_text(secrets.token_urlsafe(32))"
python tools/touch-packs/worker.py serve --host 0.0.0.0 --port 8937 --state C:/Users/arjun/.codex/bcd-touch-worker-state --token-file C:/Users/arjun/.codex/bcd-touch-worker-token.txt
```

Use a trusted local network or an HTTPS reverse proxy. For a numeric LAN address, iOS ATS may require an HTTPS endpoint; `.local` hostnames are covered by the local-network exception. Do not expose this paid-generation endpoint to the public Internet. The default listen address is loopback; `0.0.0.0` is an explicit LAN opt-in.

In the **fork's** Documents/TouchPacks/worker.json, set:

```json
{"url":"http://YOUR-DESKTOP.local:8937","token":"THE-PAIRING-TOKEN"}
```

This file is app-specific configuration, created through Files or the fork's file sharing. It is not part of the source distribution. The token grants access only to this worker; it is not a Codex account token.

After a Steam install completes, `LibraryModel.upsertSteam` queues preparation. Store-neutral new-entry saves and Game Options → Game touch pack → Prepare controls use the same path. Existing installs can use Regenerate; layout and calibration overrides are separate. There is no background iOS daemon requirement: job state survives restart and resumes when preparation/session activation runs.

The client hashes canonical identity JSON (executable, store ID, edition, build and binding digest). POST `/v1/packs/<sha256>` returns 202 while generation runs, or 200 with a pack. Polling is deduplicated; a generation nonce distinguishes explicit regeneration from repeated install notifications. The worker persists requests, validated packs, rejected candidates and receipts. One generation job runs at a time; at most three model attempts repair validation errors. An unavailable worker, bad response or invalid pack retains the current cached pack or the stock layout. Successful results activate at the next game launch or menu boundary, never under held fingers.

After three invalid candidates the same generation nonce returns 422 without calling Codex again; use Regenerate to request another attempt. Transient CLI failures return 503 during durable backoff, with at most three failed jobs per nonce. Duplicate notifications, polling and restart do not bypass those bounds.

The first-person placement policy reserves swipe space before allocating low left movement, a large right primary, nearby secondary controls and peripheral menu controls. The Chronicles adapter reads the observed named `[varcom]` key assignments, overriding model guesses; it does not decode undocumented numeric gamepad codes. The app also collects bounded known input files from the selected installation, such as bindings.json, controls.json and DefaultInput.ini. It does not crawl the disk or export registry/account files. Other games lacking reliable supplied or official binding evidence retain raw controller labels. More installed-file adapters remain useful for broader verified coverage.

Reviewed reference data lives under `references/`, separately from player remaps. The Dread reference initially recorded five historical developer defaults with dates and primary URLs: X equipment, View map, D-pad Down next weapon, Right next item and Left next spell. The owner confirmed RT Attack. The installed-input review below now supplies the additional gameplay/UI/airship bindings, with an asset hash and record offsets. The exact installed-identity pack is dread-delusion-installed-iphone.json. Earlier genuine generations used live web search and the historical evidence. The worker sets `web_search="live"` explicitly in `codex exec`; receipts distinguish enabled research from completed search calls.

The 2 November installed-input review supersedes those unresolved controller meanings for the exact Dread pilot: `references/steam-1574240-installed.json` records length-prefixed binding fields and offsets from the installed `resources.assets`, with its SHA256. RB is Block/Parry, LT Spell, LB Sprint, Y Jump, A Interact, R3 Crouch, and D-pad Up Use Item. `dread_bindings.py` enriches controller requests with empty supplied bindings using this reviewed default table, with separate on-foot/menu/airship controls and provisional compensation for the installed look processors. It leaves requests with supplied actual bindings/remaps to the generator. `inspect_unity_bindings.py ASSET --output bindings.json` can reproduce bounded extraction without writing the game file; action maps and active remaps still need review. No complete assets, saves or registry hives are distributed. Defaults are not proof that a player has kept them.

After WGI was enabled, the player confirmed movement and Attack, but rejected swipe aim. The complete pack and revised calibration were applied/read back without another IPA; physical acceptance of aim and the newly added buttons is pending. The desktop worker serves this reviewed cached pack and uses the new adapter for future matching generations. A cache edit is not another model generation.

```powershell
python tools/touch-packs/worker.py validate packs/pilots/dread-delusion.json
python tools/touch-packs/worker.py generate packs/requests/dread-delusion.json --state C:/Users/arjun/.codex/bcd-touch-worker-state
python tools/touch-packs/demo-roundtrip.py --state .touch-worker-demo/fresh-demo
python tests/host/check-touch-worker.py
```

The demo starts and terminates its own loopback worker and performs a real Codex generation. Its caller is a desktop fixture, **not an installed iPhone**. The state directory must be new to demonstrate a miss. Never run the validator with Python optimization (`-O`/`PYTHONOPTIMIZE`); it rejects that configuration.

`pack.schema.json` is the version 1 wire contract. Swift's `BCDControlPack.validate` performs on-device range, identity, reference, reachability, context, mode and reserved-area checks. Version 1 artwork is restricted to local SF Symbol names; it does not support downloaded custom artwork. Missing symbols fall back to visible output labels. Packs contain data only, with no scripts or automatic state detectors.

Generated, validated and physically tested are separate facts. Worker receipts record all three. Physical testing starts false and is never inferred from a host or simulator result. A player-confirmed test receipt must be recorded separately; the current implementation has no in-app certification button.

The real phone handoff on 2026-11-02 completed one generation (94.1 seconds, two completed searches), then activated after on-device validation. See receipts/touch/phone-generation.json. Physical testing of the installed c06 build failed; generation success does not imply usable controls. Revised input/dialog fixes require a new IPA and another physical test.
