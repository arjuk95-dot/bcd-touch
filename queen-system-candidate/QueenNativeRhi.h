#pragma once
#include "QueenBoundShaderRuntime.h"
#include "QueenBoundShaderFingerprint.h"
static unsigned char* QueenRhiImageBase = nullptr;

extern "C" void QueenNativeBoundShaderState(void* context, void* state) {
  // IOSLoadTEB is exactly the base registered as guest GS by FEX. Never use
  // native compiler TLS or raw x18 for the game's MSVC static-init epoch.
  QueenBoundShaderRuntime runtime {QueenRhiImageBase, IOSLoadTEB()};
  QueenBoundShader::set(context, state, runtime);
  static std::atomic<bool> reported {false};
  if (!reported.load(std::memory_order_relaxed) && !reported.exchange(true, std::memory_order_relaxed))
    LogMan::Msg::EFmt("[queen-rhi] native bound-shader state completed; 84 slots, original atomics/callbacks/TLS retained");
}

static void InstallQueenNativeRhi(void* mainModule) {
  const char* option = getenv("BCD_QUEEN_NATIVE_RHI");
  if (!option || strcmp(option,"1") || !CTX || !mainModule) return;
  const uintptr_t base = reinterpret_cast<uintptr_t>(mainModule);
  const auto path = FEX::Windows::GetSectionFilePath(base);
  const auto name = FEX::Windows::BaseName(path);
  constexpr const char expected[] = "queensdomain-win64-shipping.exe";
  if (name.size() != sizeof(expected)-1) return;
  for (size_t i=0;i<name.size();++i) {
    const char c=name[i]>='A' && name[i]<='Z' ? name[i]+('a'-'A') : name[i];
    if (c!=expected[i]) return;
  }
  auto image=reinterpret_cast<unsigned char*>(base);
  if (!queen_nav662::MatchesImage(base) || !QueenBoundShaderFingerprintMatches(image)) {
    LogMan::Msg::EFmt("[queen-rhi] exact image/function mismatch; original translation retained");
    return;
  }
  const auto self=queen_self_export::Resolve(reinterpret_cast<uintptr_t>(&__ImageBase),
      reinterpret_cast<uintptr_t>(&QueenNativeBoundShaderState), "QueenNativeBoundShaderState");
  LogMan::Msg::EFmt("[queen-rhi] self export raw={:#x} image={:#x} ffs={:#x} native={:#x}",
      reinterpret_cast<uintptr_t>(&__ImageBase), self.image, self.ffs, self.native);
  if (!self.ffs) {
    LogMan::Msg::EFmt("[queen-rhi] self PE export validation failed; original translation retained");
    return;
  }
  QueenRhiImageBase=image;
  const auto guestEntry=self.ffs;
  CTX->AddThunkTrampolineIRHandler(base+0x1453cf0,guestEntry);
  LogMan::Msg::EFmt("[queen-rhi] registered full bound-shader state {:#x} -> PE helper {:#x}",base+0x1453cf0,guestEntry);
}

