# External storage in the touch fork

> Fork reference reconstructed from the public v0.1.653 code and notices.
> The upstream public Git tree and source archive omit this document.
> This is not recovered upstream prose or device-test evidence.

The upstream implementation combines Madeira #464 (Connor Gow, intraducine and David Brookes) with the earlier BCD external-folder work in thebcd69/bcd-games#12 by Pardoxum. See the headers of ExternalDrives.swift and the attribution inventory in THIRD-PARTY-NOTICES.md.

Registrations retain security-scoped folder bookmarks. Games can be scanned, copied to another registered location and verified before the original is removed. Runtime guards reject movement while a game or storage operation is active.

The touch fork additionally blocks movement when a game's generated pack, queued preparation, local preset, personal edits or related preferences would lose their executable-path association. The guard runs before copy/delete and explains the restriction on the game page. Stock-only entries remain movable. Unknown or unreadable control records fail closed.

Checks: tests/host/check-external-storage.py and tests/host/check-touch-move-safety.py. Physical drive selection, interruptions, permissions, live file movement and data preservation on an iPhone remain unverified for this integration.
