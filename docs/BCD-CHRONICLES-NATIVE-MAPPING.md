# Chronicles of the Wolf: reviewed native input

## Scope

The approved floating horizontal pad emits crisp native left-stick left/right.
Deliberate deeper downward travel engages Down only while maintained. Withdrawing,
lifting, or an interruption releases it. No keyboard fallback, gyro, camera swipe,
or upward stick motion is added. A small utility radial preserves Confirm, Cancel
and native Up for menus/interactions. Four combat buttons preserve real contact
duration; Map and Inventory are separate taps.

The factory reads the already-collected, bounded `users/mobile/AppData/Roaming/Chronicles of the Wolf/config`
from the pack request. It never writes the file. Missing, duplicate, incomplete or
unsupported controller codes fail closed, leaving existing controls to the store.
Personal/researched pack precedence remains the integration owner's responsibility.

## Installed evidence

Read-only USB extraction on 2026-11-13, service closed after reading:

- `Modules/XBOXGamepad.mfx`, 84,992 bytes, SHA-256
  `85ae68187c7020bf5701e9ac9942dc7978d3b7cc426aef1445483f7e5394f25a`.
- Input config, 326 bytes, SHA-256
  `a4c526f9b3d7510500d40233cf2131862e817ece1d280dc710cf441702ff0173`.
- Cotw executable, SHA-256
  `4862f4fbbca694b4f3fd2329bc475227c63d4f8e0afd695c7ed1244d0ddff937`.
- Cotw.dat event metadata read sparsely, excluding large art/audio banks.
  This is Clickteam Fusion build 296, not GameMaker.

No game binary or serialized game event code is included in this change.
This implementation was authored from observed input contracts.

## Exact module ABI and event route

`GetRunObjectInfos` RVA `2480` publishes condition table `13278` and expression
 table `132d0`. Condition 16 at `13e0`, dispatch table `14b4`, maps:

| Code | Native output | XInput mask |
|---|---|---|
| 0 / 1 / 2 / 3 | A / B / X / Y | 1000 / 2000 / 4000 / 8000 |
| 4 / 5 | LB / RB | 0100 / 0200 |
| 6 / 7 | Back (View) / Start (Menu) | 0020 / 0010 |
| 8 / 9 | L3 / R3 | 0040 / 0080 |
| 10 / 11 / 12 / 13 | DUp / DDown / DLeft / DRight | 0001 / 0002 / 0004 / 0008 |

These test `XINPUT_STATE.wButtons` at object+`1e4`. CreateRunObject obtains
`XInputGetState`; HandleRunObject fills 16-byte states at object+`1e0`.
Expression indices 0/1 read `sThumbLX/LY` at `1e8/1ea` and return percentages
(Y negated). Game expressions 80/81 invoke those indices. Native direction
conditions -93..-96 test Dpad as an alternative. Thus both LS and Dpad are real
movement paths; the reviewed sidepad uses LS.

Expression indices 4/5 read LT/RT at `1e6/1e7`. Prologue event 166 reads game
expressions 84/85 into Xbox object alternate values 0/1. Events 173/174 associate
config codes 31/32 with those values. **31=LT and 32=RT** are game-specific
trigger cases, not entries in the module's 0..13 button dispatch.

`[varcom] M/N/O/P/Q/R/T/U` load controller variables 12/13/14/15/16/17/19/20.
Native input events map these to Attack/Jump/Special/Helper/Map/Subscreen/Confirm/Cancel.
`S` is not used: its corresponding load was not established, so no action is invented.
The installed snapshot maps M32,N0,O5,P1,Q2,R3,T6,U7 to:

- Attack RT, Jump A, Special RB, Helper B.
- Map X, Subscreen Y, Confirm View, Cancel Menu.

These are owner settings, not assumed stock defaults. Fresh pack selection parses
fresh input metadata and its binding digest. Game default/reset branches disagree
on some bindings, which is why the factory does not substitute defaults.

## Validation and remaining phone checks

`check-chronicles-pack.py` compiles the production Foundation model, validator,
factory and fixture with Swift. It checks every supported enum, current remaps,
changed trigger/button mappings, unknown/ambiguous/missing/oversize config,
CRLF/BOM, action reachability and geometry. `check-chronicles-movement-policy.py`
checks threshold/hysteresis/release/interruption and 10,000 movement trajectories.
Both passed with Swift 6.2 and host C. This is not UIKit or device validation.

Phone test: confirm menu selection/cancel, start gameplay, move left/right without
crouching, deliberately slide farther down and withdraw/lift to stand, jump while
moving, Attack/Special/Helper, Map/Inventory, and interruption release. The active
native event route and touch feel still need that physical test.
