#pragma once
#include "QueenFingerprintHash.h"
#include <cstdint>
#include <cstring>
namespace QueenGraphicsFingerprint {
inline constexpr char B0Hash[65]="a731fd77742481bab3fb3fd6a242e87c4564a205bf49e14e9a3445993623f56e";
inline constexpr size_t B0Size=441;
inline constexpr char B1Hash[65]="4c8dac5d0ec1ce1f129480b2e3b682a3cf27c5e9105b5e4392495cd24597692f";
inline constexpr size_t B1Size=1101;
inline constexpr char B2Hash[65]="b8dc408092fb64fa085b7af24ed307d91c0c774a7a91918d3e743d1f5fa5bdc7";
inline constexpr size_t B2Size=1101;
inline constexpr char B3Hash[65]="802749ada40e57099ea9fcd87deba1680ff6e0dabb3e7adad1e186f861aad718";
inline constexpr size_t B3Size=1101;
inline constexpr char B4Hash[65]="6895cecb9dbf1e50063b535835c53a001731ecfd27289840c85bf8ea36d0af1c";
inline constexpr size_t B4Size=1098;
inline constexpr char B5Hash[65]="793d255bf3c5af311fef7b49f4cdb8fe4bbd86e2db39719d8e1f461ecd5afafe";
inline constexpr size_t B5Size=1101;
inline constexpr char B6Hash[65]="0d52d6c1fec5e5043c0e0744a94d4184b34800aae47bd0b5d2e1fc360c994e7b";
inline constexpr size_t B6Size=32;
inline constexpr char B7Hash[65]="9b17a3ffdf34fb6ab4d91d3d8fe7df91a78359a8660040315cc6689cf15beaba";
inline constexpr size_t B7Size=32;
inline constexpr char B8Hash[65]="e3700de63a5b7240d251cd3f498e568aec66c866ecf0ee0c36ba6b08c07a8e50";
inline constexpr size_t B8Size=32;
inline constexpr char B9Hash[65]="95ccec70e73587a5774aba891790d21005fcb8bc5dd5c20797be24140a537791";
inline constexpr size_t B9Size=32;
inline constexpr char B10Hash[65]="e7959854ee7279862f1537c87471604d425d27367290eb274a6d1619b1b89f45";
inline constexpr size_t B10Size=32;
inline constexpr char B11Hash[65]="3fe48b830328325da01e153032aa0605f953467e84a90f0a03bf598c717e7bdd";
inline constexpr size_t B11Size=8;
inline constexpr char B12Hash[65]="2fe4f45e0594d331883b71ea1f5b5783f7bdff5f886db56dd0fc8e06b65029df";
inline constexpr size_t B12Size=266;
inline constexpr char B13Hash[65]="80ba0f1d6896efc4b4609523e1ca5234afc3a681ba64c5dff0944cd796ef3cd3";
inline constexpr size_t B13Size=102;
inline constexpr char B14Hash[65]="1d46b29974555dbc04534f33cc7bdbed4f5ab8440ce03f3f815060e4e95812de";
inline constexpr size_t B14Size=94;
struct Region{uint32_t rva,size;const char (&hash)[65];};
inline constexpr Region Regions[]={
{0x1438f00,B0Size,B0Hash},
{0x1432240,B1Size,B1Hash},
{0x14319a0,B2Size,B2Hash},
{0x1431100,B3Size,B3Hash},
{0x1431df0,B4Size,B4Hash},
{0x1431550,B5Size,B5Hash},
{0x14393e0,B6Size,B6Hash},
{0x1432690,B7Size,B7Hash},
{0x14395d0,B8Size,B8Hash},
{0xf2f040,B9Size,B9Hash},
{0xf32880,B10Size,B10Hash},
{0x376a598,B11Size,B11Hash},
{0x3a0e3b0,B12Size,B12Hash},
{0x3a0e670,B13Size,B13Hash},
{0x3a0e6e0,B14Size,B14Hash},
};
inline constexpr uint32_t Timestamp=0x6ae3dac2, ImageSize=0x5043000;
}
// Call only after existing Queen image/mapped-range gate.
inline bool QueenGraphicsCommitFingerprintMatches(unsigned char* image) {
 using namespace QueenGraphicsFingerprint;
 uint32_t nt,stamp,size; uint16_t mz; std::memcpy(&mz,image,2); if(mz!=0x5a4d)return false;
 std::memcpy(&nt,image+0x3c,4);if(nt<0x40||nt>0x100000)return false;
 std::memcpy(&stamp,image+nt+8,4);std::memcpy(&size,image+nt+24+56,4);
 if(stamp!=Timestamp||size!=ImageSize)return false;
 for(const auto& r:Regions)if(r.rva>size||r.size>size-r.rva||!queen_fingerprint_hash::Matches(image+r.rva,r.size,r.hash))return false;
 return true;
}
