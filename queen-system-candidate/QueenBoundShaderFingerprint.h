#pragma once
#include "QueenFingerprintHash.h"
#include <cstdint>
#include <cstring>
// Exact owned PE; invoke only after existing image-identity/mapping gate.
inline bool QueenBoundShaderFingerprintMatches(const uint8_t* image) {
    static constexpr char BoundShaderStateHash[65]="92df359befa9be58e43d29c3d74597ac6686f4f08945f44722eb2188e34f3560";
  static constexpr size_t BoundShaderStateSize=814;
  if (!queen_fingerprint_hash::Matches(image+0x1453cf0,BoundShaderStateSize,BoundShaderStateHash)) return false;
    static constexpr char MayDeleteNowHash[65]="8bc1b0f43ddf9da5c32b21a80997c59858c780279ab568caaa81a82a1506627d";
  static constexpr size_t MayDeleteNowSize=32;
  if (!queen_fingerprint_hash::Matches(image+0x776410,MayDeleteNowSize,MayDeleteNowHash)) return false;
    static constexpr char DeferDeleteHash[65]="da3044f0a9c2bda6dc5d7ad9ec74dfa39b30f96735504803b3bf7c9005b55e17";
  static constexpr size_t DeferDeleteSize=32;
  if (!queen_fingerprint_hash::Matches(image+0x7d6a00,DeferDeleteSize,DeferDeleteHash)) return false;
    static constexpr char InitHeaderHash[65]="7c5210e53de698c63039dd2d2d408741b4a73b0a202179dc34143646ea3acee4";
  static constexpr size_t InitHeaderSize=32;
  if (!queen_fingerprint_hash::Matches(image+0x36af1d4,InitHeaderSize,InitHeaderHash)) return false;
    static constexpr char InitFooterHash[65]="fcce9507826f82c421f4f821ef62953e0062d31f5f0fc65fc4faabf536ae5eda";
  static constexpr size_t InitFooterSize=32;
  if (!queen_fingerprint_hash::Matches(image+0x36af174,InitFooterSize,InitFooterHash)) return false;
    static constexpr char InitFlagHash[65]="d96c07c651d0c0807428ed5dce9d171506411189bc3a059c69193896205ff06e";
  static constexpr size_t InitFlagSize=32;
  if (!queen_fingerprint_hash::Matches(image+0x143f6f0,InitFlagSize,InitFlagHash)) return false;
    static constexpr char ConditionalCommitHash[65]="c80b7ac8daed86f2b547385611a4f34e7cbac8f75c4a84756fd57f0f9397e047";
  static constexpr size_t ConditionalCommitSize=32;
  if (!queen_fingerprint_hash::Matches(image+0x1437f70,ConditionalCommitSize,ConditionalCommitHash)) return false;
  return true;
}
