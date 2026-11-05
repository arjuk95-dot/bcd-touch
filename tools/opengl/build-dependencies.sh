#!/bin/bash
# GPL-3.0-or-later WITH the Madeira Converter Exception, version 1.
# Rebuild both native GL dependencies; no donor binaries are used.
set -euo pipefail
R=$(cd "$(dirname "$0")/../.." && pwd)
W="$R/build/opengl-dependencies"
mkdir -p "$W" "$R/app/Madeira/gl" "$R/app/Madeira/licenses"
MVK_SHA=db66022459ffb663aa2b50f6b018bc2e124f5edf
MESA_SHA=592272df3cf01e85e7db300c449df5061092574d099da275d19e97ef0510f8a6
if [ ! -d "$W/MoltenVK/.git" ]; then
  git init "$W/MoltenVK"
  git -C "$W/MoltenVK" remote add origin https://github.com/KhronosGroup/MoltenVK.git
  git -C "$W/MoltenVK" fetch --depth 1 origin "$MVK_SHA"
  git -C "$W/MoltenVK" checkout --detach FETCH_HEAD
fi
test "$(git -C "$W/MoltenVK" rev-parse HEAD)" = "$MVK_SHA"
export MOLTENVK_SRC="$W/MoltenVK"
bash "$R/build/moltenvk-ios/build.sh"
if [ ! -f "$W/mesa-25.0.7.tar.xz" ]; then
  curl --fail --location --retry 3 https://archive.mesa3d.org/mesa-25.0.7.tar.xz -o "$W/mesa-25.0.7.tar.xz"
fi
echo "$MESA_SHA  $W/mesa-25.0.7.tar.xz" | shasum -a 256 -c -
test -d "$W/mesa-25.0.7" || tar -xf "$W/mesa-25.0.7.tar.xz" -C "$W"
python3 -m venv "$W/venv"
"$W/venv/bin/pip" install meson==1.7.2 ninja==1.11.1.3 mako==1.3.9 pyyaml==6.0.2 packaging==24.2
export MESA_SRC="$W/mesa-25.0.7" MESA_VENV="$W/venv"
bash "$R/build/mesa-ios/build.sh"
python3 "$R/tools/opengl/inspect-dependencies.py"
git -C "$W/MoltenVK" submodule status --recursive > "$R/app/Madeira/gl/source-submodules.txt"
python3 "$R/tools/opengl/record-build-inputs.py"
