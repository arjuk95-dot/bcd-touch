#!/bin/bash
set -euo pipefail
R=$(cd "$(dirname "$0")/../.." && pwd)
TC="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
for pair in i686:i386-windows:x86 x86_64:arm64ec-windows:x64; do
  arch=${pair%%:*};rest=${pair#*:};farm=${rest%%:*};suffix=${pair##*:}
  "$TC/$arch-w64-mingw32-clang" -O2 "$R/tests/opengl/smoke.c" -o "$R/app/Madeira/$farm/bcd-opengl-smoke-$suffix.exe" -lopengl32 -lgdi32 -luser32
done
