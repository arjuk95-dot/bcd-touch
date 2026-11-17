#pragma once
#include <cstdint>
#include <cstddef>
#include "QueenFingerprintHash.h"
namespace queen_guest_leaf {
inline constexpr uint32_t TlsTimestamp=0x6ac23a1c, TlsImageSize=0x2f0000, TlsBodyRva=0x6d470;
inline constexpr size_t TlsBodySize=76;
inline constexpr char TlsBodyHash[]="ef0a6d526b7dbf59859d63943fe6335d936e212a447e84c52c2dd95bfc39af26";
inline constexpr uint32_t ThreadIdTimestamp=0x69ef9a27, ThreadIdImageSize=0xc0000, ThreadIdBodyRva=0x26530;
inline constexpr size_t ThreadIdBodySize=8;
inline constexpr char ThreadIdBodyHash[]="2cd2e66965664d6db479cfda70b36379122fdd170a858a0fedbbc08aead303c8";
}
