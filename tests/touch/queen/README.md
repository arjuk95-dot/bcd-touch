# Queen controller factory / gesture integration

Run pure policy assertions:
`swiftc app/Madeira/BCDQueensGesturePolicy.swift tests/touch/queen/main.swift -o /tmp/queen-policy && /tmp/queen-policy`

Factory requires schema v6 controller+relativeMouse and twoFingerTap support from integration owner. Journal doubletap is declared only when caller supplies a verified controller `bindings["journal"]`; there is no keyboard injection. Run has no shipped controller binding and is deliberately unresolved.

UIKit must own unoccupied right-side surface touches and call policy begin/move/end. Moves precede clock advance. attackDown/up map to factory attack output RT; holding remains RT=1 and release RT=0. A tiny pulse must be queued across actual delivery ticks (not coalesced in one frame). A swipe must continue relative mouse look and must not block an independently held button. cancelAttack on a second finger immediately; only independently validated stationary two-finger gestures invoke twoFingerTap. Cancel all policy state and release all held outputs on focus loss, context change, touch cancellation, or radial opening. Stationary tap/charge must not acquire touches already owned by move, button, radial or UI. No gyro.

The factory's attack `gesture` control is a semantic anchor, not a visible Attack button. Runtime must suppress its visual and consume the entire free aim surface through policy. Existing generic swipe-up/down recognition must not reinterpret a Queen attack candidate.

Local defaults were independently extracted from installed v1.01.03 DefaultInput.ini (verified embedded SHA1 d4e7a3684b94a91d144903de3c1a6da3d0838197). No retail data or configuration included here. Personal remaps must be verified before passing overrides; do not infer Journal=R3 or Run=L3.

Current cloud environment lacks swift/swiftc, so executable tests must run in integration/macOS CI. Do not report this as simulator or phone validation.
