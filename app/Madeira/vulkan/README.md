# Windows Vulkan resources

This folder is bundled by the app's Xcode project. `tools/build-vulkan-dlls.sh`
builds `winevulkan.dll` and `vulkan-1.dll` from the pinned Wine source into
`arm64ec-windows/`. Those generated DLLs are ignored by Git and must be built
and verified before the app archive is packaged.

The experimental per-game setting `vulkan = moltenvk` enables this route for
64-bit Windows programs. The session setup links these DLLs only for that
opt-in session and uses the bundled `gl/libMoltenVK.dylib`. Vulkan remains off
when the setting is absent or the required components are missing. This is
not a 32-bit Vulkan backend, and these DLLs must not be copied into the normal
ARM64EC runtime farm for every session.

Build verification: `tools/check-vulkan-shipped.py` checks the generated
components. See `tests/host/check-vulkan-bcd.py` for the source-level routing,
bundle and build checks. These checks do not establish game compatibility
or successful Vulkan rendering on a phone.

This note was reconstructed from the public v0.1.653 build and session code
because its public source omitted the resource README expected by the checks.
It is not recovered upstream documentation or device-test evidence.
