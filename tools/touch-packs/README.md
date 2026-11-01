# Desktop control-pack worker

Python 3.11+, `pip install jsonschema==4.26.0`, and an authenticated Codex CLI are required. `codex login` stays on the desktop; no OpenAI credential is copied to iOS. The phone uses only a scoped worker pairing token. Codex is invoked with a read-only sandbox, medium reasoning, an explicit JSON output schema, an isolated temporary directory and no user MCP configuration. The model receives supplied binding metadata; this worker does not browse manuals automatically. Unknown bindings must remain unresolved.

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

The first-person placement policy reserves swipe space before allocating low left movement, a large right primary, nearby secondary controls and peripheral menu controls. The Chronicles adapter reads the observed named `[varcom]` key assignments, overriding model guesses; it does not decode undocumented numeric gamepad codes. Other games without supplied binding evidence retain raw controller labels. New installed-file adapters and curated official binding evidence are still needed for broader verified coverage.

```powershell
python tools/touch-packs/worker.py validate packs/pilots/dread-delusion.json
python tools/touch-packs/worker.py generate packs/requests/dread-delusion.json --state C:/Users/arjun/.codex/bcd-touch-worker-state
python tools/touch-packs/demo-roundtrip.py --state .touch-worker-demo/fresh-demo
python tests/host/check-touch-worker.py
```

The demo starts and terminates its own loopback worker and performs a real Codex generation. Its caller is a desktop fixture, **not an installed iPhone**. The state directory must be new to demonstrate a miss. Never run the validator with Python optimization (`-O`/`PYTHONOPTIMIZE`); it rejects that configuration.

`pack.schema.json` is the version 1 wire contract. Swift's `BCDControlPack.validate` performs on-device range, identity, reference, reachability, context, mode and reserved-area checks. Version 1 artwork is restricted to local SF Symbol names; it does not support downloaded custom artwork. Missing symbols fall back to visible output labels. Packs contain data only, with no scripts or automatic state detectors.

Generated, validated and physically tested are separate facts. Worker receipts record all three. Physical testing starts false and is never inferred from a host or simulator result. A player-confirmed test receipt must be recorded separately; the current implementation has no in-app certification button.
