#pragma once
#include <cstdint>
namespace QueenGraphicsGuestFp {
// Byte-for-byte x64 SSE helpers, non-EC guest page. All ABI args are pointers;
// no native FP conversion or FP return-value ABI crosses the boundary.
// Narrow: MOVSD xmm0,[rcx]; CVTPD2PS xmm0,xmm0; MOVD [rdx],xmm0; RET.
inline constexpr uint8_t NarrowBytes[]={0xf2,0x0f,0x10,0x01,0x66,0x0f,0x5a,0xc0,0x66,0x0f,0x7e,0x02,0xc3};
// Expand: MOVD xmm0,[rcx]; CVTPS2PD xmm0,xmm0; MOVSD [rdx],xmm0; RET.
inline constexpr uint8_t ExpandBytes[]={0x66,0x0f,0x6e,0x01,0x0f,0x5a,0xc0,0xf2,0x0f,0x11,0x02,0xc3};
// Touch: MOVSD xmm0,[rdx]; UCOMISD xmm0,[rcx]; JE +4; MOVSD [rcx],xmm0; RET.
// JE includes unordered on x86. This MUST NOT become native C++ !=.
inline constexpr uint8_t TouchBytes[]={0xf2,0x0f,0x10,0x02,0x66,0x0f,0x2e,0x01,0x74,0x04,0xf2,0x0f,0x11,0x01,0xc3};
using Op=void(*)(const void*,void*);
// Set exactly once at ProcessInit on a process-lifetime, non-EC guest page.
// Require same allocation/invalidation contract as X64ReturnInstr; do not call
// raw x64 bytes as native ARM64 or publish before copy/notification completes.
inline Op Narrow=nullptr,Expand=nullptr,Touch=nullptr;
inline bool Ready(){return Narrow&&Expand&&Touch;}
}
