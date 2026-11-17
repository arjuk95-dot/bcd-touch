#pragma once
#include <cstdint>

// This source overlay is ONLY for the Queen-selected alternative FEX DLL.
// Freeze the table before main ThreadInit; no live updates/unloads are supported.
namespace FEXCore::Core {
struct QueenGuestLeafTarget {
  uint64_t Native;
  uint64_t Guest;
};
static_assert(sizeof(QueenGuestLeafTarget) == 16);
extern QueenGuestLeafTarget QueenGuestLeafTargets[64];

inline uint64_t QueenGuestLeafLookup(uint64_t native) {
  const auto &slot = QueenGuestLeafTargets[(native >> 3) & 63];
  return slot.Native == native ? slot.Guest : 0;
}
// Call only at ProcessInit, after exact module/body verification and before
// first guest ThreadInit. A collision fails closed, never replaces another API.
inline bool QueenGuestLeafRegister(uint64_t native, uint64_t guest) {
  if (!native || !guest || native == guest) return false;
  auto &slot = QueenGuestLeafTargets[(native >> 3) & 63];
  if (slot.Native && (slot.Native != native || slot.Guest != guest)) return false;
  slot = {native, guest};
  return true;
}
}
