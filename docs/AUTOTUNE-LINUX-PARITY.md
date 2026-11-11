# Auto-tune Linux parity experiment

This experiment does not remove tests from the Mac archive or change app behavior.
The workflow is manual-only. Do not dispatch a duplicate Mac replay while another
required build is running. The next required Mac check can add
`--parity-output parity.json` to its normal `--suite all` command instead.

## Coverage split

- `--suite all` remains the default: all structural checks, all fixture replays,
  engine checks and app-glue modes off/on/default.
- `--suite core` runs the same structural checks, replay and engine sources on
  Linux or macOS. It keeps every fixture, chunk sizes 0/4093/7, normal-end reruns,
  exact comparisons and ordinary checked Swift compilation.
- `--suite glue` is explicitly Mac-only and keeps the app-integration modes. Its
  production source imports Darwin/os and uses Mach task memory APIs. Linux
  Foundation/UserDefaults behavior does not substitute for Apple's implementation.
- Explicit split modes and parity output fail if Swift is missing. No fixture is
  blessed or edited; parity output cannot be combined with --bless.

## Reproducibility

The manual experiment selects Xcode 16.4 on Mac and official Swift 6.1.2 for Ubuntu
22.04, verifies the exact version, and checks the Linux archive SHA-256:
`ed40901b5bccf9022ff5d41425e2316f8e710a7e0c99717ba62080744e81fd66`.
The archive was downloaded over HTTPS from download.swift.org. This pins bytes,
not an inferred Docker tag. Production Swift sources need no Linux shim in the
initial compile experiment. For a sandbox without a writable default Clang
module cache, set CLANG_MODULE_CACHE_PATH and SWIFT_MODULECACHE_PATH to a writable
temporary directory; this is a compiler cache location, not a code change.

Reports contain the checkout commit, platform/toolchain version, SHA-256 of every
core source/test harness/fixture input, all replay JSON (including facts), every
required normal-end result, and complete engine-check output. Comparison requires
both suites to pass, matching source/fixture bytes and commit, all expected
fixtures/chunks, and exact replay/engine equality. Missing or mismatched artifacts
fail. A local dirty-checkout run is preliminary evidence, not a claim of parity
with a later published commit.

## Before moving coverage

1. Obtain full successful Linux and Mac reports for the same final source.
2. Run `compare-autotune-parity.py` against both reports on that checkout.
3. Record wall time and Actions cost separately from correctness. Three workers
   are bounded; no speedup is assumed in advance.
4. Only after parity, require the Linux core job and Mac glue job before archive.
   Keep Apple SDK, simulator, native compiler/linker, archive and signing work on
   Mac. A Linux pass alone does not authorize removing the existing Mac gate.

## Checked test optimization

`--optimize-core` is opt-in and affects only the replay and engine test executables.
It uses `-O -assert-config Debug`, never `-Ounchecked`. Before compiling either
executable, a positive control must run and separate Swift `assert` and
`precondition` negative probes must trap with their expected diagnostics. Missing
proof fails the check. The app build and the Mac glue flags are unchanged.

The complete Linux experiment matched all 826 fixture records, 2,503 replay
results and all engine output. The archive keeps the full Mac suite during the
cross-platform validation run and emits the same report as the Linux job.
No Mac coverage is removed merely because the Linux job passes.
