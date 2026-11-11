# itch.io support reference

> Fork reference reconstructed from the public v0.1.653 code and notices.
> The upstream public Git tree and source archive omit this document.
> This is not recovered upstream prose or device-test evidence.

The experimental SwiftItch integration is controlled by env.BCD_ITCH. The API work follows go-itchio (MIT) as knowledge, as described in THIRD-PARTY-NOTICES.md. This upgrade does not turn the integration on or alter credentials.

Checks: tests/host/check-itch.py and tests/host/check-itch-7z.py. They cover source integration, format validation and the bounded 7-Zip reader; they do not establish live account or device behavior.
