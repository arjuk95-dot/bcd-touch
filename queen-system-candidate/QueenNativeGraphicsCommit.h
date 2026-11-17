#pragma once
#include "QueenGraphicsCommitRuntime.h"
#include "QueenGraphicsFingerprint.h"
static unsigned char* QueenGraphicsImageBase = nullptr;
static bool QueenGraphicsHostAFP = true;

extern "C" void QueenNativeGraphicsCommit(void* context) {
  QueenGraphicsCommitRuntime runtime {QueenGraphicsImageBase};
  QueenStageCommit::commitGraphics(context, runtime);
  static std::atomic<bool> reported {false};
  if (!reported.load(std::memory_order_relaxed) && !reported.exchange(true, std::memory_order_relaxed))
    LogMan::Msg::EFmt("[queen-graphics] whole graphics-resource commit completed; five stages, original UAV helpers retained");
}

static void InstallQueenNativeGraphicsCommit(void* mainModule) {
  const char* option = getenv("BCD_QUEEN_NATIVE_GRAPHICS");
  if (!option || strcmp(option,"1") || !CTX || !mainModule) return;
  if (!IosEcExitLean || !QueenGraphicsCommitRuntime::FpReady(QueenGraphicsHostAFP)) {
    LogMan::Msg::EFmt("[queen-graphics] FP/exit gate unavailable; original translation retained");
    return;
  }
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
  if (!queen_nav662::MatchesImage(base) || !QueenGraphicsCommitFingerprintMatches(image)) {
    LogMan::Msg::EFmt("[queen-graphics] exact image/function mismatch; original translation retained");
    return;
  }
  const auto self=queen_self_export::Resolve(reinterpret_cast<uintptr_t>(&__ImageBase),
      reinterpret_cast<uintptr_t>(&QueenNativeGraphicsCommit), "QueenNativeGraphicsCommit");
  LogMan::Msg::EFmt("[queen-graphics] self export raw={:#x} image={:#x} ffs={:#x} native={:#x}",
      reinterpret_cast<uintptr_t>(&__ImageBase), self.image, self.ffs, self.native);
  if (!self.ffs) {
    LogMan::Msg::EFmt("[queen-graphics] self PE export validation failed; original translation retained");
    return;
  }
  QueenGraphicsImageBase=image;
  const auto guestEntry=self.ffs;
  CTX->AddThunkTrampolineIRHandler(base+0x1438f00,guestEntry);
  LogMan::Msg::EFmt("[queen-graphics] registered whole graphics-resource commit {:#x} -> PE helper {:#x}",base+0x1438f00,guestEntry);
}

