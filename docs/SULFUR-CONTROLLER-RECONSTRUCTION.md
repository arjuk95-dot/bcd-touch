# SULFUR native controller profile reconstruction

This is fresh reconstruction, not recovery of the missing prior checkpoint. The latest owner direction supersedes the earlier keyboard profile: native XInput for game actions, relative mouse only for swipe look. No shared Store/Surface/schema files changed in this isolated patch.

## Native mapping evidence
Exact transferred assemblies: Core2,357,760bytes SHA25670542851b8bbb561186b53ef4ffd1f66249863a6a0044057c5f2c7b878f7f300; Gameplay744,960bytes SHA256e9f6655bc59a8147fdbab0a6787f233d43195a931c5598e2f7ab6a9a1f3cb859. Manifest-matched Unity.InputSystem.dll1,095,168bytes SHA256390aa3800421d3076344c2ea4954ea371edd1423e34b3db98d49cd033d3c6c5e maps Submit→South→XInputA and Cancel→East→XInputB.

- Move LS; camera uses relative mouse instead of RS.
- Attack RT; Melee X; Interact and Reload A (native same-button semantics).
- Alternate attack/aim LT; alternate melee LB (hold-capable More selection).
- Inventory Start/Menu; pause Select/View; swap Y; jump B; alternate jump RB (not separately exposed); crouch R3; amulet DUp; inspect DDown.
- Sprint L3 is a press-triggered toggle, NOT held sprint. No Shift/WASD output is included.

Approved geometry keeps the larger Attack to the LEFT of Melee, Interact above, clear lower-right swipe look, floating left movement, slow actions in More. Eight More slots include manual Sprint; it is not a claim of synchronized automatic state.

## Automatic sprint integration contract
`BCDSulfurSprintChoice` stores versioned `native-l3-entry-v1` / `disabled-v1`. Missing preference requests the verified shipped Windows Hold default. Runtime must supply actual hash proof for all reviewed DLLs and the startup settings bundle before enabling that default, and must gate unsupported current Always mode/remaps when known. The tuple `sprintDefaultsFile` is the exact242,104,512-byte asset and hash; stream it rather than allocate the whole asset, once per launch. Explicit saved nativeL3 is a user configuration declaration, not a current-settings read. Old Shift-choice tokens fail closed.

L3 `ToggleSprint` flips state in all modes; Always inverts the output, so the entry gesture requires known Hold/Toggle compatibility, not blind Always support. `CalculateMovementVelocity` clears lockedSprint and sprintToggled when calculated direction is zero. Crouch-slide, disable and mode changes also reset. Nonzero backward/lateral motion does not itself prove stopping; ADS/low speed can suppress actual sprint without clearing the latch. Therefore never emit an assumed exit/off pulse: a native reset could make that pulse turn sprint ON.

The separate policy emits one entry request per deliberate forward contact. On lift/interruption, neutralize LS and release any in-flight L3, with no exit pulse. Neutral must actually be processed by the guest. External controller changes, frame stalls and native state resets can invalidate host-side assumptions; do not claim synchronization or phone validation. The gesture must not rearm within the same contact.

## Inventory limitation
No mouse item drag/cancel is supplied by this factory. Exact IL found Esc refuses active drag; RMB uses items. `InventoryUI.Update` method06001C77 offsets006B–00A9 can handle OpenInventory and SetState(0), guarded by lock16/closedThisFrame/attribute96. SetState06001C9F0255–0268→DroppedOnInvalid06001FE9 may restore saved rotation/originGrid/paperdoll or fallback placement then GenericDragEnd06001FD8. Normal EndDrag06001FE0 uses cached hoveredSlot/HoveredItem, not a guaranteed final-event raycast. Thus neither an immediate pointer-return/release nor Tab press then left-up is an unconditional interruption-safe cancel. Any approved pointer-context exception requires separate guarded integration and device validation; do not silently port STS2 RMB cancellation.

## Validation
Fresh Python data-contract test passes canonical embedded/pilot equality and hash, all native action mappings, alias proof, reachable actions, Attack/Melee geometry and reserved swipe region. The included production Swift test function is ready for the integration harness but has NOT been compiled/run here: this current Linux workspace lacks the previous Swift toolchain and Apple SDK. Shared V6 validation must explicitly allow controller + relativeMouse; all other profiles remain untouched. Native compile, simulator routing and phone game test remain required.

## Installed verifier API
`BCDSulfurInstalledVerifier.verify(executableURL:verifyShippedDefault:)` accepts the actual host-drive URL resolved by the caller and returns `Proof(buildVerified:defaultVerified:)`. It verifies the executable name/file, canonical containment, exact sizes and streamed SHA256 of all three DLLs. The optional startup default check uses a1MiB buffer; pass false when the saved preference does not need shipped-default resolution. No database/settings are read or modified. Integrator must call once per launch, gate activation on the proof, and still treat current remaps/Always mode as unknown unless separately verified or explicitly declared.

Synthetic production verifier tests cover exact/corrupt bytes, wrong sizes, bad hashes, out-of-root symlinks and incomplete installation. Tests are supplied but not executed until a Swift/CryptoKit host is available. No game bytes are fixtures.

## Same-pack inventory context (current integration)
The final factory contains `onFoot` and `inventory`. It reuses the same LS movement control, exposing only native X MoveItem, A Use/Select, B Back/Close, and LB/RB rotation buttons in inventory. Combat action controls and More entries are onFoot-only. No item-dropY, sort, bulk transfer, mouse drag or invented cancel is supplied. The open action ID `inventory` pulses Menu; `inventory-close` pulses B. Shared runtime must switch overlay context only after delivering the pulse, release old contacts, suppress camera/sprint in inventory, and preserve explicit mode-only resync when a request is refused. This overlay state is user intent, not guest state detection. `MoveItem` maps the game's native action; its detailed pickup/place lifecycle still needs phone validation.

The earlier standalone inventory prototype commit3c31aacd is not part of this branch and must not be cherry-picked for current integration. This commit is directly based on the common factory/verifier checkpoint6ae3a36b.
