"""The dxmt revision the fork's winemetal / dxmt / airconv patch checks start from.

madeira-bcd: since the 2026-10-15 upstream merge the dxmt pin (128b297) carries
the fork's patches that went upstream (willfaust/dxmt #9 and #21-#33), so a
check that applies a patch to the pin as committed would find it already there.
Those checks start from OVERLAY_BASE, the pin the patches were written against,
instead: rev() names it (fetched into the dxmt checkout when a shallow clone
lacks it) when the pin carries the wave, else HEAD as before. CI builds from the
new pin plus the same patches, which leaves the same files (the pin's own
additions are those patches' output; checked when the merge was made).
"""
from pathlib import Path
from overlay_base import ensure_overlay_base

OVERLAY_BASE = 'db546ee466ad50ec6463edb5fa183de11db43761'
OVERLAY_TREE = 'a24bd7aad0c5087cabfc183353b58ee6c2f6f79c'
OVERLAY_UPSTREAM = 'https://github.com/willfaust/dxmt.git'
PIN_MARKER = 'madeira_rp_lean_on'   # willfaust/dxmt#26, in the wave's pin and later


def rev(dxmt):
    dxmt = Path(dxmt)
    wm = dxmt / 'src/winemetal/unix/winemetal_unix.c'
    if not wm.is_file() or PIN_MARKER not in wm.read_text(errors='ignore'):
        return 'HEAD'
    return ensure_overlay_base(dxmt, OVERLAY_BASE, OVERLAY_TREE, OVERLAY_UPSTREAM)
