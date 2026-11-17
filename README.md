# BCD667 experimental Queen candidate

Unsigned, not device-validated. This branch preserves the existing runtime fixes,
adds optional diagnostics gating, allocation scan-floor repair and an optimized
Release app build. Original FEX summary/cost instrumentation remains active.
No performance or battery improvement is claimed before device measurement.

Build inputs are pinned existing PUBLIC arjuk95-dot/bcd-touch source and Actions
artifacts. No private source bundle or private release is retrieved. Game identity
checks use SHA256 region fingerprints, not embedded retail game code. Private layout-record regression fixtures and their dependent tests are omitted
from this public branch and retained privately. Other host tests remain.
No retail game files are distributed; users supply their own games.

Preserve666 for rollback. BCD_QUEEN_DIAGNOSTICS=1 opts into additional diagnostics
on a fresh app launch. This is not a zero-instrumentation build.

Some nonfunctional binary-provenance prose and checksums are omitted from public
source. Control actions, mappings, identity validation and runtime behavior remain
unchanged except the owner-approved per-call literal checksum lookup removal; private audit records retain the omitted evidence.

The per-call table-utility checksum lookup is removed in this public experiment.
Title/session/focus guards remain; game-version compatibility is not expanded
or newly proven. Only the final unsigned IPA and its SHA256 are retained by CI,
not raw objects, compiled archives, input archives or diagnostic logs.

Known regression versus666: the TLS binary rewrite is omitted. The verified
donor kernelbase.dll is preserved byte-for-byte. Optional guest-leaf optimization
rejects the unmatched optimized body and uses the original APIs; normal TLS/game
functionality remains. This candidate cannot isolate the benefit of other667
changes from the loss of that prior optimization. Phone testing remains required.
