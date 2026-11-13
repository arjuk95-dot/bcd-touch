# Native table utilities: bounded evidence

This isolated, unused pure helper preserves the approved pointer surfaces and
personal controls. It returns XInput **masks**, matching TouchPadAction.buttons
in TouchGamepad.swift, not raw-pad ordinals. Integration must own press/release,
focus cancellation and exact installed-file hashing. It does not assert current
remaps or device validation. Inventory requires an explicitly eligible game
context; an overlay label alone cannot prove that context.

SKALD static PE/IL inspection: SkaldIO.update polls ControllerInputControl;
getPressedMainInteractKey / getPressedEnterKey consume A, getPressedEscapeKey B,
getPressedInventoryKey consumes X only with its argument enabled,
getPressedJournalKey consumes menuButton. ControllerInputControl.cctor binds
these to Unity key codes330/331/332/337 (joystick0/1/2/7). Retained installed
InputManager supports joystick input. Both exact SHA256 values are in the helper.
No trigger/bumper mapping is exported: internal names conflict with physical
indices. No guessed Map or hover-inspection button is exported.

STS2 exact DLL SHA2560861bfa1df347538d932f22d580e75420f08082792eb914e53b4882764acdbe9
has a Godot/XInput fallback when Steam is unavailable or no Steam controller is
active. Native semantic default map includes Cancel=east, Map=select,
Select=south, Confirm/EndTurn=north. Retained physical project input actions are
missing, so this helper FAILS CLOSED for all STS2 utilities. This is not proof
that the game lacks raw controllers. L3 Peek is combat/overlay peek, not card
hover-only inspection, and must never replace approved safe pointer inspection.

Portable test: cc -std=c11 -Wall -Wextra -Werror
 tests/host/table_native_utilities_checks.c -o /tmp/table-native && /tmp/table-native
Native Swift/UIKit/guest runtime execution remains untested.

## Exact STS2 project input recovered
Full retained PCK SHA256 c60f672ee7804e6aefa1e19a582fa1c80b126a7b0eef4d084d3abf110df2eab7 (1990705700 bytes) matches transferred manifest. Its project.binary at offset1989151520,length24693 hashes88bc2e4f6a2627204b20a714cb8746a269c009e48255dcfc7a0eaef9503d2227. Exact Godot InputEventJoypadButton device=-1 records establish east1=B,select4=View. Combined with native IL these enable only Cancel/Map. Installed proof reads the bounded project block plus exact code DLL, rather than rehashing2GB of unrelated assets. Current remaps and physical runtime still require device testing.

SKALD exact managed filename is SKALDAssembly.dll (1043968 bytes), not Assembly-CSharp.dll. Startup input asset is409276bytes. Runtime utility verifier path corrected.
