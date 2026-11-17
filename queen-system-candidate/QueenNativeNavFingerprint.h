#pragma once
#include "QueenFingerprintHash.h"
#include <cstdint>
#include <cstring>
namespace queen_nav662 {
inline constexpr uintptr_t KernelRVA=0x2f708f0;
inline constexpr char Expected0Hash[65]="ab75c9c5c949d36729c8a89e81a169f4ed2c1aaa51b83acef98bb7e65830161c";
inline constexpr size_t Expected0Size=1113;
inline constexpr char Expected1Hash[65]="a79ad31c7b82bead9d395bcf25c91e8cf5e9fee74109292ab62da3d7da55065f";
inline constexpr size_t Expected1Size=16;
inline constexpr char Expected2Hash[65]="bdb404cc26c8b79c87b2641bdcdcca468f28516d1fb1b99d0e9557ef37c5c376";
inline constexpr size_t Expected2Size=16;
inline bool MatchesImage(uintptr_t base) {
 const auto b=reinterpret_cast<const unsigned char*>(base);
 if(!base || b[0]!=0x4d || b[1]!=0x5a) return false;
 uint32_t peoff; std::memcpy(&peoff,b+0x3c,4);
 if(peoff!=0x208) return false;
 if(std::memcmp(b+peoff,"PE\0\0",4)) return false;
 uint16_t machine,magic; uint32_t stamp,size;
 std::memcpy(&machine,b+peoff+4,2); std::memcpy(&stamp,b+peoff+8,4);
 std::memcpy(&magic,b+peoff+24,2); std::memcpy(&size,b+peoff+24+56,4);
 if(machine!=0x8664 || magic!=0x20b || stamp!=0x6ae3dac2 || size!=0x5043000)return false;
 return queen_fingerprint_hash::Matches(b+0x2f708f0,Expected0Size,Expected0Hash) && queen_fingerprint_hash::Matches(b+0x3ae9d30,Expected1Size,Expected1Hash) && queen_fingerprint_hash::Matches(b+0x40e46b0,Expected2Size,Expected2Hash);
}
}
