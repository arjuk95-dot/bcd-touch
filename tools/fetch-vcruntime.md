# Fetch the Visual C++ runtime

This document was reconstructed for the public v653 integration from the committed
`tools/fetch-vcruntime.sh`, `tests/host/check-vcruntime.py`,
`tests/host/check-vcruntime-sources.py`, and `tests/host/check-vcruntime-mfc.py`.
The original document is absent from both the public v653 Git tree and source
archive. This is new documentation of the available code, not recovered upstream prose.

## Extract and check

Run `./tools/fetch-vcruntime.sh` from the repository. It downloads Microsoft's
x64 redistributable from `https://aka.ms/vs/17/release/vc_redist.x64.exe`, or uses
an existing installer selected with `VCRUNTIME_INSTALLER`.
Requirements are curl, python3 and cabextract, plus msiextract from msitools when
an extracted layer is an MSI. On macOS: `brew install cabextract msitools`.

The default destination is `app/Madeira/x86_64-vcruntime`; `VCRUNTIME_DEST` selects
another destination. The extraction scans the embedded cabinets of the WiX Burn
bundle and nested cabinet/MSI layers. It accepts AMD64 candidates, not same-name
ARM64 payloads, and preserves the selected DLL bytes.

Run `python3 tests/host/check-vcruntime.py --strict` for the default folder, or set
`VCRUNTIME_DIR` to check another folder. The checker requires every listed file,
a PE32+ image and a complete certificate-table payload. This is a structural
check, not cryptographic Authenticode verification or a grant of redistribution rights.
Do not truncate certificate data when copying the files.

## Fourteen files

- concrt140.dll
- msvcp140.dll
- msvcp140_1.dll
- msvcp140_2.dll
- msvcp140_atomic_wait.dll
- msvcp140_codecvt_ids.dll
- vcamp140.dll
- vccorlib140.dll
- vcomp140.dll
- vcruntime140.dll
- vcruntime140_1.dll
- vcruntime140_threads.dll
- mfc140.dll
- mfc140u.dll

## Runtime sources

The app's runtime source selection combines the build's DLL folder with
`Documents/vcruntime`. User-folder DLLs override matching bundled names without
regard to case; non-DLL files are not linked into the game's system32. An absent
or empty user folder leaves the bundled selection unchanged. Without either
source, there are no runtime DLLs to link.

MFC is enabled by default; a game's `env.MADEIRA_MFC = 0` disables its MFC links.
The in-app runtime installer is separate from this developer extraction script.
Use Microsoft's distribution and applicable licence terms for these proprietary
files; this document does not change their licensing.
