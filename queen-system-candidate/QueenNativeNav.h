// Queen-only ARM64EC helper. Included by the ARM64EC PE Module.cpp, never Mach-O.
// Fingerprints and the independently verified scalar kernel are supplied separately.
#pragma once
#include "QueenNativeNavFingerprint.h"
#include "QueenNativeNavKernel.h"
#include "QueenSelfExport.h"

extern "C" void QueenNativeLedgeFilter(void* context, int height, int climb, queen_nav662::HF* hf) {
  // ARM64EC compiler emits the mixed-ABI indirect-call checker for this call.
  // Do not translate a guest callback into a raw Apple ARM64 function pointer.
  using Timer = void (*)(void*, int);
  const auto timer = [context](unsigned offset) {
    auto vtable = *reinterpret_cast<uintptr_t**>(context);
    auto callback = reinterpret_cast<Timer>(vtable[offset / sizeof(uintptr_t)]);
    callback(context, 8);
  };
  if (*reinterpret_cast<const volatile uint8_t*>(static_cast<uint8_t*>(context) + 9)) timer(0x20);
  queen_nav662::Filter(height, climb, hf);
  // Original re-reads the flag: start callback may disable the stop callback.
  if (*reinterpret_cast<const volatile uint8_t*>(static_cast<uint8_t*>(context) + 9)) timer(0x28);
  alignas(8) static std::atomic<uint64_t> completed {0};
  if (completed.fetch_add(1, std::memory_order_relaxed) == 0)
    LogMan::Msg::EFmt("[queen-nav] native ledge filter completed; original timer callbacks preserved");
}

static void InstallQueenNativeNav(void* mainModule) {
  const char* option = getenv("BCD_QUEEN_NATIVE_NAV");
  if (!option || strcmp(option, "1") != 0 || !CTX || !mainModule) return;
  const uintptr_t base = reinterpret_cast<uintptr_t>(mainModule);
  auto path = FEX::Windows::GetSectionFilePath(base);
  auto name = FEX::Windows::BaseName(path);
  constexpr const char expected[] = "queensdomain-win64-shipping.exe";
  if (name.size() != sizeof(expected) - 1) return;
  for (size_t i = 0; i < name.size(); ++i) {
    const char c = name[i] >= 'A' && name[i] <= 'Z' ? name[i] + ('a' - 'A') : name[i];
    if (c != expected[i]) return;
  }
  // This compares the known PE identity, complete kernel and constant tables.
  // No activation on a name-only match; no executable or game data bytes changed.
  if (!queen_nav662::MatchesImage(base)) {
    LogMan::Msg::EFmt("[queen-nav] image fingerprint mismatch; original translation retained");
    return;
  }
  const auto self = queen_self_export::Resolve(reinterpret_cast<uintptr_t>(&__ImageBase),
      reinterpret_cast<uintptr_t>(&QueenNativeLedgeFilter), "QueenNativeLedgeFilter");
  LogMan::Msg::EFmt("[queen-nav] self export raw={:#x} image={:#x} ffs={:#x} native={:#x}",
      reinterpret_cast<uintptr_t>(&__ImageBase), self.image, self.ffs, self.native);
  if (!self.ffs) {
    LogMan::Msg::EFmt("[queen-nav] self PE export validation failed; original retained");
    return;
  }
  // Resolve only an executable alias, never rewrite any guest data pointer.
  const uintptr_t guestEntry = self.ffs;
  CTX->AddThunkTrampolineIRHandler(base + queen_nav662::KernelRVA, guestEntry);
  LogMan::Msg::EFmt("[queen-nav] registered validated main-image kernel {:#x} -> PE helper {:#x}",
                    base + queen_nav662::KernelRVA, guestEntry);
}

