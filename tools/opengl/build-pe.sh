#!/bin/bash
set -euo pipefail
R=$(cd "$(dirname "$0")/../.." && pwd)
cd "$R"
bash build/wine-pe/build-modules.sh opengl32
SKIP_DXMT=1 bash build/wine-i386/build.sh opengl32
TC="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
export PATH="$TC:$PATH"
B="$R/wine/build-aarch64-gl"
mkdir -p "$B"
if [ ! -f "$B/Makefile" ]; then
 (cd "$B" && ../configure --enable-archs=aarch64 --without-x --without-vulkan --without-freetype --without-gnutls --disable-tests --with-wine-tools="$R/wine/build-native")
fi
make -C "$B" -j"$(sysctl -n hw.ncpu)" dlls/opengl32/aarch64-windows/opengl32.dll
"$TC/aarch64-w64-mingw32-strip" --strip-debug "$B/dlls/opengl32/aarch64-windows/opengl32.dll"
cp "$B/dlls/opengl32/aarch64-windows/opengl32.dll" app/Madeira/aarch64-windows/opengl32.dll
python3 tools/opengl/verify-runtime.py --built
