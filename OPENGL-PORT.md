# Optional desktop OpenGL — WO-BCD-OPENGL-001

Implementation and native builds in progress. Hardware/Noita/Direct3D regression acceptance remain pending.

## Base and donors

Branch `wo-bcd-opengl-001`, starting `352af1b5461efbeeca94bb1a1c322a6e394de02c`, upstream v0.1.630 `53e7e8c73b62633b1d94c75b451fcc775928378f`. Noita touch app source `6a9905306e474c9fd38292ac06c327e56bd96228` is preserved. Native baseline: Actions 42081514633 (not an OpenGL build).

Unchanged gitlinks: Wine `469e08af66c2638b74422e3d068620d400272d55`, FEX `d4f2e6eb2e99bde1b53c452d5c824e2a467d7102`, DXMT `8ae252b401bdee3ba725e391fba24dc2792f21af`, Dock `72558e416a390f3669457930f09a389e54f49556`.

* Porthole `0786a24fa97647491c942db6279ad3610dcbb48a`: only opengl32 hunks of consolidated 0174. The 0172 engine patch is a comparison reference, not applied wholesale or stacked with historical 0082.
* Connor Gow Madeira `a14444490087c9504a19b9a168482ab35df2fc6c` (`opengl-test-7`): iOS WGL driver, IOSurface/Metal presenter, Mesa cross file and six patches, Mesa/MoltenVK recipes. Original author credits AI assistance. Porthole's imported binaries and untested device claims are not acceptance evidence.
* Mesa 25.0.7 tar SHA-256 `592272df3cf01e85e7db300c449df5061092574d099da275d19e97ef0510f8a6` (later Mesa removed OSMesa).
* MoltenVK v1.4.2 `db66022459ffb663aa2b50f6b018bc2e124f5edf`; ExternalRevisions/fetched submodules accompany the source build.

No donor binaries, LuaJIT substitutions, memory reservations, short-map fallbacks, audio changes, SDL hints, FEX/DXMT/Dock replacements or input changes are imported. Heavy builds run on macOS CI.

## Integration map

All three opengl32 PE DLLs (ARM64EC, ARM64, i386) and native dispatch tables build from the same patched BCD Wine source. Generated WoW64 thunks distinguish guest pointers, handles and bound-buffer offsets. Explicit `mov xN,x18` TEB reads use BCD's existing safe TLS rewrite, avoiding donor stack-saving trampolines that conflict with BCD's ARM64EC SP-alignment fix.

Native opengl32 objects are in libntdll_unix.a. Win32u registers winios_OpenGLInit from opengl_ios.c. Native libraries are embedded and signed under Frameworks; provenance is bundled under gl-info. Desktop GL loads bundled OSMesa/Zink → MoltenVK → Metal. This does not enable Windows Vulkan games. Actual renderer strings reject software fallback; donor GL4.1/GLSL410 version inflation and implicit GLES fallback are removed.

WiniosGL.m shares BCD's existing fullscreen/per-window CAMetalLayer. Three BGRA IOSurfaces use explicit CPU locks, GL finish and Metal completion waits before reuse/resize/destruction. Bottom-up orientation is handled by the presentation shader. Background gating waits at GL presentation/context boundaries; physical interruption tests are still required.

GL drawable callbacks feed the launch/frame counters and frame-time ring once. DXMT's GPU meter is hidden during GL output. Frame caps and WGL intervals pace GL. MetalFX/frame generation are not integrated for GL. Logs identify backend, library errors, requested context, vendor/renderer/version/GLSL, missing procedures, Metal device and presentation failures.

## Build and use

Select Xcode26.3. `bash tools/opengl/build-dependencies.sh` builds pinned sources; no donor graphics binaries. Run established touch-ipa.yml with successful `gl_dependency_run`. Matching native/PE dispatch, architecture, load-command and hash gates precede archive. Existing Touch sideload packaging preserves the app identity and signing process.

Update existing BCD with the same SideStore account; do not uninstall/deactivate/reset library, onboarding or JIT. Save/close the game first. Game details → Display → Desktop OpenGL (Zink). Fully close/restart BCD, enable JIT normally, then launch. Exportable per-game config: `gl-backend = zink`. Rollback: `gl-backend = off` and full app restart. Default Off preserves existing Direct3D routing. No game files, remaps or saves are changed.

## Verification distinctions

Host policy checks cover disable/software rejection/frame caps. Windows smoke programs, compiled for x86 and x64, exercise GL3 context/share/make-current/delete, missing procedure, textured shader scene, FBO/readback, repeated presents, resize, intervals and cleanup. `--disabled` expects context failure. Compilation does not mean hardware execution.

Pending physical gates: installed Noita PE architecture and actual settings; hardware smoke; Noita playable mines/effects/cursor/movement/flight/casting/inventory/transitions/save/relaunch; logs/capture/FPS/frame time/memory/thermal; background/orientation; matched Dread Delusion and another available Direct3D path; GL Off comparison and launcher/touch regression.

Repository transfer verified: https://github.com/arjuk95-dot/bcd-touch (same repository ID 1441826178 and all original branches).

Wine ARM64EC DLLs have AMD64 (`0x8664`) PE headers with CHPE metadata and mixed ARM64EC/AMD64 code ranges. The gate checks that metadata and audits TEB instructions only in native ranges; a header-only ARM64EC assumption is incorrect. The per-game picker persistence test executes production row construction, the routing branch, setLine and GameProfile storage against unique test files, verifying cold read, export/reset and other-game isolation.
