#include "../QueenFingerprintHash.h"
#include "../QueenNativeNavFingerprint.h"
#include "../QueenBoundShaderFingerprint.h"
#include "../QueenGraphicsFingerprint.h"
#include "../QueenGuestLeafFingerprint.h"
#include <cstdio>
#include <vector>
int main(){std::vector<uint8_t>b;int c;while((c=getchar())!=EOF)b.push_back(uint8_t(c));uint8_t h[32];queen_fingerprint_hash::Digest(b.data(),b.size(),h);for(auto v:h)printf("%02x",v);puts("");}
