#!/bin/bash
set -Eeuo pipefail
# Exact retained workflow excerpts; do not compile unrelated runtimes.
ROOT="$PWD"
# Host-tool failures must show their build/configure error, never silently exit.
report_header_failure() {
  rc=$?
  for name in wine-native-configure.log wine-native-make.log wine-configure.log; do
    if [ -f "$ROOT/$name" ]; then echo "=== $name (last 60 lines) ==="; tail -60 "$ROOT/$name"; fi
  done
  exit "$rc"
}
trap report_header_failure ERR
export PATH="$(brew --prefix bison)/bin:$(brew --prefix flex)/bin:$PATH"
test "$(git -C wine rev-parse HEAD)" = 52a6004e68e818c5b09918215e973726e282425f
export GITHUB_WORKSPACE="$ROOT"

# Work around wine's uncommitted arm64ec_x64_export_iat.c
(
cd "$ROOT"
F=wine/dlls/ntdll/arm64ec_x64_export_iat.c
if [ -f "$F" ]; then
  echo "::notice::$F is present upstream now -- this step can go"
else
  printf '/* placeholder: see build-ipa.yml; PE-side only, never compiled here */\n' > "$F"
  echo "::warning::$F missing from the wine fork -- empty placeholder written for makedep"
fi
# dlls/ntdll/unix/sync.c includes build/madeira_cfg.h BEFORE config.h,
# on purpose (ml1122: Wine's headers ban strncpy by macro). makedep
# treats that ordering as fatal, so configure never writes a
# Makefile. Upstream builds from a long-configured tree and never
# meets it. Make that one sanity check a warning.
MD=wine/tools/makedep.c
python3 - "$MD" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'fatal_error( "%s must be included before other headers\\n", file->name );'
new = ('fprintf( stderr, "%s:%d: warning: %s must be included before other headers '
       '(madeira-bcd CI: not fatal)\\n", input_file_name, input_line, file->name );')
if new in s:
    print("makedep: already patched")
elif s.count(old) == 1:
    open(p, "w").write(s.replace(old, new))
    print("makedep: config.h ordering check is now a warning")
else:
    print("::error::makedep.c anchor not found -- wine moved, review this step")
    sys.exit(1)
# The WoW64 series' wine (125hz pr/wow64-core) includes Madeira's
# iOS shim headers (ios_fastsync.h, ios_srv_stats.h, ...) by bare
# name; the iOS builds find them with -I build/ntdll-unix/shims,
# makedep does not and stops configure. They are outside the tree
# like a system header, so skip them the way makedep skips those.
s = open(p).read()
old = '    if (make->external) return NULL; /* ignore missing files in external libs */\n'
new = old + ('    if (!strncmp( source->name, "ios_", 4 )) return NULL;  '
             '/* madeira-bcd CI: build/ntdll-unix/shims */\n')
if new in s:
    print("makedep: ios_* shims already skipped")
elif s.count(old) == 1:
    open(p, "w").write(s.replace(old, new))
    print("makedep: missing ios_* shim headers are skipped")
else:
    print("::error::makedep.c external-lib anchor not found -- wine moved, review this step")
    sys.exit(1)
PYEOF

)

# Build native wine (for host-side tools: widl/wrc/wmc)
(
cd "$ROOT"
cd wine
mkdir -p build-native
cd build-native
# LOCAL (x86_64 Mac): an x86_64 host's configure defaults to a 32-bit Wine,
# which macOS cannot build ("gcc -m32 works... no"); arm64 hosts are 64-bit.
W64=""; [ "$(uname -m)" = x86_64 ] && W64=--enable-win64
../configure $W64 > "$GITHUB_WORKSPACE/wine-native-configure.log" 2>&1
# Only the host tools and the generated headers are used from this
# tree. A full host build also compiles the iOS-only unix sources
# for macOS, and one failure there used to stop make before widl.
N=$(sysctl -n hw.ncpu)
{ make -j"$N" __tools__ && make -j"$N" include; } > "$GITHUB_WORKSPACE/wine-native-make.log" 2>&1

)

# Configure wine (build-macos, cross)
(
cd "$ROOT"
cd wine
mkdir -p build-macos
cd build-macos
../configure --enable-win64 --disable-tests \
  CC="xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=17.0" \
  CROSSCC="xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=17.0" \
  --host=aarch64-apple-darwin --build=x86_64-apple-darwin \
  --with-wine-tools="$GITHUB_WORKSPACE/wine/build-native" \
  --without-freetype --without-fontconfig \
  --without-x --without-opengl --without-vulkan \
  --without-gnutls --without-pcsclite --without-usb \
  --without-v4l2 --without-gphoto --without-inotify \
  --without-sane --without-pulse --without-alsa --without-oss \
  --without-capi --without-cups --without-krb5 --without-ldap \
  --without-netapi --without-sdl --without-udev --without-unwind \
  > "$GITHUB_WORKSPACE/wine-configure.log" 2>&1 || true

)

# Generate cross-tree headers and patch config.h for iOS SDK
(
cd "$ROOT"
make -C wine/build-macos include -j"$(sysctl -n hw.ncpu)" > "$GITHUB_WORKSPACE/make-include.log" 2>&1 || true
cp -n wine/build-native/include/*.h wine/build-macos/include/ 2>/dev/null || true
CFG=wine/build-macos/include/config.h
{
  echo ""
  echo "/* iOS SDK fixups appended by CI */"
  echo "#undef HAVE_GETATTRLIST"
  echo "#ifndef D_TAPE"
  echo "#define D_TAPE 1"
  echo "#endif"
  echo "#ifndef D_DISK"
  echo "#define D_DISK 2"
  echo "#endif"
  echo "#ifndef D_TTY"
  echo "#define D_TTY 3"
  echo "#endif"
  echo ""
  echo "/* Wine configure runs --without-gnutls here (the host has no"
  echo " * gnutls for the iOS sysroot), so config.h defines neither of"
  echo " * these. But dlls/bcrypt/gnutls.c is wrapped head-to-toe in"
  echo " * #ifdef HAVE_GNUTLS_CIPHER_INIT and dlls/secur32/schannel_gnutls.c"
  echo " * in #ifdef SONAME_LIBGNUTLS -- undefined, both compile to an"
  echo " * EMPTY object, __wine_unix_call_funcs is never emitted, and the"
  echo " * app link dies on _bcrypt_unix_call_funcs / _secur32_unix_call_funcs."
  echo " * We link toolchains/gnutls-ios statically and ios_gnutls_shim.h"
  echo " * rewrites dlopen/dlsym onto a static symtab, so the soname string"
  echo " * is only ever pattern-matched, never actually dlopen()ed. */"
  echo "#ifndef SONAME_LIBGNUTLS"
  echo "#define SONAME_LIBGNUTLS \"libgnutls.so.30\""
  echo "#endif"
  echo "#ifndef HAVE_GNUTLS_CIPHER_INIT"
  echo "#define HAVE_GNUTLS_CIPHER_INIT 1"
  echo "#endif"
} >> "$CFG"
if [ -f wine/build-macos/include/dwrite.h ]; then
  echo "::notice::dwrite.h present in cross tree"
else
  echo "::error::dwrite.h STILL MISSING"
  LS=$(ls wine/build-native/include/ 2>&1 | head -40 | python3 -c "import sys; print('%0A'.join(sys.stdin.read().splitlines()))")
  echo "::error::native include dir :: $LS"
  T=$(tail -n 20 "$GITHUB_WORKSPACE/make-include.log" 2>/dev/null | python3 -c "import sys; print('%0A'.join(sys.stdin.read().splitlines()))")
  echo "::error::make include tail :: $T"
fi

)
test -x wine/build-native/tools/widl/widl
test -s wine/build-macos/include/config.h
test -s wine/build-macos/include/winnt.h
