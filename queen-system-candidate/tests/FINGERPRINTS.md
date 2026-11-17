# Hash-only version gates

The Queen navigation, bound-shader and graphics-resource guards retain their original image identity checks and25 exact RVA/length regions. Expected retail instruction bytes are not included: each region is checked using SHA-256 at registration. No game file is modified and no hash runs per frame. Mismatch fails closed, as before; practical cryptographic identity replaces literal byte equality.

`python3 tests/check-fingerprint-hash.py` compiles all guard headers and tests the portable dependency-free hash against Python hashlib over140 vectors including every size0–129, padding/block boundaries, randomized input and one million bytes.

Private integration verification (not distributed as fixtures) also compared all25 original regions and rejected75 first/middle/last byte mutations. No retail fixtures are needed to run the public hash tests.

Purpose-written executable guest surrogate bytes remain executable code. Wine library fingerprint signatures are separate from the retail Queen regions and retain their original provenance requirements. This source-only check does not establish native ARM64EC build success or phone performance.

Wine guest-leaf validation also uses SHA-256, with the original 80-byte TLS
and 8-byte thread-ID lengths, PE timestamp/image-size and bounded mapped reads.
No native DLL body arrays are published. `QueenGuestLeafSurrogates.S` is our
readable x64 implementation of the documented/pinned TEB ABI, not extracted
retail or Wine machine code. `apply-guest-leaf-install.py` invokes
`generate-guest-leaf.py` to assemble it locally with clang's x86_64 ELF target,
reject relocations and produce the build-local `QueenGuestLeafBytes.h`.
The generator has a GNU cc fallback for x86_64 Linux tests. Neither a generated
header nor an object file belongs in the public source snapshot.

Private regression tests compiled the actual templated Verify function with
mocked mapped reads: both original DLL bodies passed, all 88 single-byte
mutations failed, unreadable mappings and altered PE identities failed.
Assembly output for both surrogates exactly matched the preexisting 74-byte
and 9-byte implementations. These host tests do not replace ARM64EC build or
device validation. The full platform installer was not compiled by host tests.
