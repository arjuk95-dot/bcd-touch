# Selected one-shot TEST IPA lane

Prepared for one intentional Mac build. Publication and runner startup must be
verified before reporting the build as running.

## Decision and limits

The full run 43073552781 ended in failure at 18:35:37 UTC on 2026-11-11. Its
retained round-624 aggregate could not retrieve an exact historical DXMT commit
from the migrated origin. There is no active full-build head start to preserve.
The selected route fixes that source lookup and builds a clearly labeled TEST
IPA while broad regressions remain pending. The first TEST attempt, run
43082543311, then stopped at a timing-dependent HUD test assertion before native
engine compilation. The reader could start after every producer had finished.
This follow-up changes only the host test: capture its cursor before producers
start, drain the stable tail after they finish, and test the forced late-reader
schedule explicitly. The production ring and every original assertion remain
unchanged. No failed gate was removed to hide
that failure, and no full-suite success or phone validation is claimed.

Avoiding 441 broad Check stages should remove substantial test work, but native
compilation, retained gates, new-branch cache misses and queue time remain. No
precise completion-time estimate is justified. This lane does not launch a
second full Mac build.

## Baseline and full inventory

- Historical-source fix: `2b8c45cba26bd34783de41340e46e726d37c84f0`.
- Audited fixed tree: `6e86b8507da1bfb53dd1154f63f8c46dc76050d8`.
- Unchanged production baseline: `01aaaa5c187052db06352fa77a51b5c0d8944e2b`.
- Existing full workflow: `.github/workflows/touch-ipa.yml`, unchanged.
- TEST workflow: `.github/workflows/touch-test-build-first.yml`.
- Original 746 steps: 304 retained and 442 deferred. Of 521 Check stages,
  80 remain and 441 are deferred. The remaining deferred step uploads the omitted
  auto-tune parity report. Both optional parity jobs are absent.
- Four additions: exact-source guard, early historical-source regression/live
  availability checks, TEST metadata, and verified partial-validation receipts.
- Candidate total: 308 steps. LLVM setup moves from original step 225 to step 60.

`docs/touch-build-first-inventory.json` lists all 746 original steps individually,
with retain/defer reason, script paths, condition, ID and exact recipe hash. It
also records omitted optional jobs, narrow artifact changes and branch-filter
hashes. Every retained original step keeps its relative order.

## What remains exact

All production sources, submodule pins and build scripts remain unchanged. The
historical-source fix changes four host-test helper/regression files. The
follow-up adds the test-only reader scheduling correction described above. The early guard
hashes every other Git tree record, excludes only the four option files and two
controlled workflow filters, verifies those filter files' exact hashes, rejects
tracked worktree changes, and requires complete matching recursive submodules.

All 17 original step IDs and consumers, all 24 cache restore/save operations,
keys, paths and conditions, all production setup/patch/build/generation/staging/
license/version/archive steps, and all 14 original Verify gates remain exact.
The Intel runner, Xcode 26.3, environment, permissions and timeout are unchanged.

The missing-runtime fallback remains the existing hash-pinned v0.1.653 release,
not v630 or a whole old IPA. Existing hash-pinned, unchanged 7-Zip programs retain
their guard. Existing-slot packaging retains source/IPA digests, main/helper
identities, callbacks, instruction hashes, ad-hoc signing, entitlement and strict
signature checks, ZIP validation and rejection of personal provisioning profiles.
Personal signing, installation and data-preservation testing are not done.

## Historical sources and non-obvious Check dependencies

The shared resolver preserves each historical commit and pins its independently
verified tree. It tries the original public upstream only after the current
origin explicitly says that exact ref is absent. Authentication, access,
transport, timeout, malformed object and integrity failures stay hard failures.
It never moves checkout HEAD, refs, origin configuration or FETCH_HEAD.

- DXMT: `db546ee466ad50ec6463edb5fa183de11db43761`, tree
  `a24bd7aad0c5087cabfc183353b58ee6c2f6f79c`, original `willfaust/dxmt`.
  The five aggregate-72 users remain: gpu-stall, gpu-time-wow64, d9-texfmt,
  d9-query-stuck and d11-query-stuck. Later full-suite users are sc-native,
  rp-lean and fps-gov. All share the fixed helper.
- FEX: `3bec2ac498bf78156ab47c0c194b0e8cb2849756`, tree
  `e348431369f07995227d15e1ecf90fbf3c4d90c6`, original `willfaust/FEX`.
  Its seven full-suite users share the other fixed helper. This second migrated-
  origin failure was verified and repaired before a later full-suite attempt.

Immediately after checkout/source guard and before any UI checks, the lane runs:

    python3 tests/host/check-overlay-base.py
    python3 tests/host/check-overlay-base.py --verify-checkouts

The second command checks both real historical objects without changing shipping
pins. Later checks reuse the verified objects.

Check names alone were not used to decide omission. Wine steps 259/260 really
patch production file.c and remain. DXMT chain callers 34/72/78 remain because
the Metal atomics helper's default follows its own __file__, potentially modifying
the real shader despite temporary cwd. Inspection of all 66 extracted patchers
found no other such default; this is static evidence, not exhaustive tracing.

Omitted BCD Host/start-helper checks write non-installed test outputs; retained
production stages independently rebuild/install them. Omitted host FFmpeg checks
produce host-only caches, not iOS libraries; dependent checks 312/313 are deferred
together. Preview caches are not the native archive. Auto-tune uses --check, and
its fixture rewriting requires the absent --regen option. No coverage is reported
as passed merely because it was deferred.

## TEST markers and artifacts

Before archive/signing, Info.plist gains TEST_ONLY_FULL_SUITE_PENDING, prior
full-run ID 43073552781, prior result FAILED, and device status NOT_RUN. No identity,
version, display name, entitlement or executable code is changed by the marker.
Both generated IPA markers are verified after unchanged existing-slot packaging.
The separate JSON/text receipts state full suite pending, prior run failure and
phone validation not run. Build success is never represented as full validation.

Both artifact names gain `-TEST-full-suite-pending`. All original IPA, package
receipt, provenance, catalog, GL provenance and log paths remain; the two TEST
receipt files are added. No release, upload-to-third-party or installation step
is introduced.

## Exactly one intended launch

Target branch: `wo-bcd-v653-test-first-004`.

Only this branch is in the new workflow's push filter. Its job additionally
requires the exact repository/ref, event push, created=true and deleted=false.
There is no manual, schedule, create or workflow_run trigger. Later ordinary
pushes have created=false and cannot allocate another Mac runner. A separate
non-cancelling concurrency group cannot cancel another workflow.

GitHub documents the push payload's created/deleted booleans:
https://docs.github.com/en/webhooks/webhook-events-and-payloads#push

In this branch only, touch-checks.yml and opengl-checks.yml each gain the exact
branch in branches-ignore. Their jobs, paths and other events remain identical.
The validator removes only that new filter and compares the entire parsed
workflow against the fixed baseline, then checks every other workflow's push
branch filters. Full/preview/pipeline remain restricted to the integration branch;
other native workflows target main/other named branches or manual invocation.
The validator lives at tools/check-build-first-option.py, outside broad touch
path filters, but runner isolation does not depend on path-diff assumptions.

Publication plan: upload the reviewed objects/commit without moving existing
refs; verify the target branch does not exist; create that new branch directly
at the final reviewed commit. Do not create a seed branch and then update it,
since that later push correctly fails the creation-only guard. Verify exactly
one Mac build for the final SHA. If no push run appears, inspect the actual
publication event/permissions; do not blindly repush, recreate the branch, add a
manual dispatch or broaden the guard. Default/integration refs stay untouched.

GitHub cache scope is unchanged: the new branch may read matching default-branch
caches but not integration-branch-only caches. There is no sharing of unfinished
job outputs and no cache-key broadening.

## Validation and outstanding work

Passed locally: 17 resolver regressions; actionlint on all three touched
workflows; exact retained recipe/ID/cache comparisons; source fingerprint and
production-diff checks; exact-only branch exclusions; all other automatic trigger
checks; shell syntax; TEST identity/receipt fixtures and missing-marker rejection;
negative mutations of mandatory patches, cache keys, triggers, concurrency,
artifact paths and exclusion scope. The resolver was also smoke-tested against
both real missing current-origin refs, upstream fallbacks and verified cache hits.

Not run: the corrected Mac build, the whole broad regression suite, native signing/
packaging on this lane, installation or phone behavior. These remain pending.

## Follow-up HUD test validation

The test-only correction preserves all 32 original assertions and adds three.
The original delayed-reader schedule failed 5/5 times. Corrected ASan/UBSan
stress passed 50/50 runs and ThreadSanitizer passed 20/20 runs locally. Restoring
the late cursor initialization or removing the final drain each failed 5/5
negative runs. These are Linux host results, not Mac or phone validation.
LeakSanitizer was disabled because the local ptraced environment cannot run it;
ASan, UBSan and TSan remained enabled. Native CI sanitizer settings are unchanged.

## Fresh launch after stalled GitHub queue (2026-11-12)

Run 43097430578 for the prior `wo-bcd-v653-test-first-002` branch remained
queued with no jobs after approximately twelve hours. GitHub's signed-in
web UI returned `Failed to cancel workflow`. The owner authorized one fresh
build despite the possibility that the stale run may eventually start too.
This launch changes only the exact one-shot branch references, their
validated suppression hashes, and this record. App/runtime sources,
submodule pins, the HUD test correction, every retained build/check step,
and TEST/full-suite-pending markers are unchanged from commit
`3f8ac7d76761110a7508081f28a2f8dfb02635f0`.
No prior run, branch, default-branch file, or production source is modified.

## Menu harness correction after run 43186580068

The Mac run passed the corrected HUD test, preserved touch controls, OpenGL
checks, and the menu's 101 behavior checks, gate sanitizers and six iPhone
source compiles. It stopped on a Python TypeError in an optional unbuilt-Wine
reporting path before engine compilation. Three calls had reversed the existing
`check(condition, label)` arguments. This revision corrects only their argument
order; all conditions, assertions, native/runtime files and submodule pins remain
unchanged. All six optional/required fallback cases pass locally and the six
original cases reproduce the TypeError. A read-only audit of all 341 Python
scripts directly invoked by the retained workflow found no other reversed
condition/label call. These are host/script checks, not native or phone approval.
The exact source fingerprint now binds the corrected test as well. Branch 004
launches one isolated replacement; no active run or existing ref is modified.
Full regressions remain pending and phone validation remains not run.
