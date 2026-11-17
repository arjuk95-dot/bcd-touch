#!/bin/bash
set -euo pipefail
# Header generation only. The retained LLVM static libraries are not rebuilt.
root="$PWD"; source="$root/toolchains/llvm-project"
if [ ! -d "$source/.git" ]; then
 git clone --depth 1 --filter=blob:none --sparse --branch llvmorg-15.0.7 https://github.com/llvm/llvm-project.git "$source"
 git -C "$source" sparse-checkout set llvm cmake
fi
test "$(git -C "$source" rev-parse HEAD)" = 8dfdcc7b7bf66834a761bd8de445840ef68e4d1a
sed -i '' 's/MATCHES "Darwin"/MATCHES "Darwin|iOS"/' "$source/llvm/cmake/modules/AddLLVM.cmake"
cmake -S "$source/llvm" -B toolchains/llvm-host-build -G Ninja \
 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
 -DLLVM_TARGETS_TO_BUILD="" -DLLVM_INCLUDE_TESTS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_INCLUDE_BENCHMARKS=Off
cmake --build toolchains/llvm-host-build --target llvm-tblgen -j3
cmake -S "$source/llvm" -B toolchains/llvm-ios-build -G Ninja \
 -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
 -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
 -DLLVM_TABLEGEN="$root/toolchains/llvm-host-build/bin/llvm-tblgen" \
 -DCMAKE_MACOSX_BUNDLE=OFF -DLLVM_BUILD_UTILS=Off -DLLVM_BUILD_TOOLS=Off -DLLVM_TARGETS_TO_BUILD="" \
 -DLLVM_INCLUDE_TESTS=Off -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_INCLUDE_BENCHMARKS=Off -DLLVM_INCLUDE_UTILS=Off \
 -DLLVM_ENABLE_TERMINFO=Off -DLLVM_ENABLE_LIBXML2=Off -DLLVM_ENABLE_ZSTD=Off -DLLVM_ENABLE_ZLIB=Off
cmake --build toolchains/llvm-ios-build --target intrinsics_gen -j3
test -s toolchains/llvm-ios-build/include/llvm/IR/Attributes.inc
test -s toolchains/llvm-ios-build/include/llvm/IR/IntrinsicEnums.inc
