# EA support reference

> Fork reference reconstructed from the public v0.1.653 code and notices.
> The upstream public Git tree and source archive omit this document.
> This is not recovered upstream prose or device-test evidence.

SwiftEA follows the Maxima protocol research (GPL-3.0; Sean Kahler, Nick Whelan, Paweł Lidwin and contributors) as knowledge, not copied code, as recorded in THIRD-PARTY-NOTICES.md.

The experimental entry is gated by env.BCD_EA. It is off. This integration does not enable it or change accounts.

Checks: tests/host/check-ea-formats.py exercises the format layer and tests/host/check-ea.py checks integration and production Swift fixtures. These checks do not establish live EA sign-in, downloads or device execution.
