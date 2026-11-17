#pragma once
#include "QueenStageCommit.h"
namespace QueenStageCommit {
// Research reconstruction of WHOLE1438f00..14390b9 orchestration.
// Shader pointer offsets on bound state: VS28,PS30,HS38,DS40,GS48.
// Runtime must provide original helpers14393e0/1432690/14395d0 (or a separately
// proven native implementation) and image RVA376a540 empty-array sentinel.
// These UAV helper implementations remain a material native-island boundary.
template<class Runtime> void commitGraphics(void* context,Runtime& rt) {
 uint32_t index=read<uint32_t>(context,0x17ce0);
 index=index?index-1:9999;
 auto state=read<void*>(context,0x4460+uintptr_t(index)*8);
 auto pixel=read<void*>(state,0x30);
 if(pixel) {
  const uint32_t mask=read<uint16_t>(pixel,0xbc)&read<uint32_t>(context,0x27cc);
  const uint32_t previous=read<uint32_t>(context,0x27d0);
  uint16_t dirty;
  const bool canGrow=rt.uavGrowthFastPathEnabled() && (mask&~previous)!=0 && (previous&mask)==previous;
  if(canGrow) {
   write<uint32_t>(context,0x27d0,mask);
   dirty=read<uint16_t>(context,0x43ce);
  } else if(previous!=mask) {
   write<uint32_t>(context,0x27d0,mask);
   rt.resetPixelUav(context,true); // Original14393e0; can mutate context.
   dirty=0xffff;
  } else dirty=read<uint16_t>(context,0x43ce);
  uint32_t pending=read<uint32_t>(pixel,0x30)&dirty;
  uint32_t changed=0;
  while(pending) {
   unsigned ub=0;while(((pending>>ub)&1u)==0)++ub;
   pending^=uint32_t(1)<<ub;
   auto uniform=read<void*>(context,0x4278+uintptr_t(ub)*8);
   auto layout=read<uint8_t*>(uniform,0x18)+0x78;
   const void* entries;
   if(read<int32_t>(layout,8)==0)entries=rt.emptyResourceTable();
   else {
    const intptr_t tagged=read<intptr_t>(layout,0);
    entries=(tagged&1)?reinterpret_cast<const void*>(reinterpret_cast<uintptr_t>(layout)+(tagged>>1)):
                       reinterpret_cast<const void*>(tagged);
   }
   changed+=rt.commitPixelUav(context,static_cast<uint8_t*>(context)+0x178,uniform,
                            read<void*>(pixel,0x58),ub,entries); //1432690
  }
  if(changed||read<uint32_t>(context,0x27c8))rt.flushPixelUav(context); //14395d0
 }
 // Preserve exact stage order and state rereads after earlier callbacks.
 if(auto shader=read<void*>(state,0x28))commit(context,shader,Stages[0],rt);
 if(pixel)commit(context,pixel,Stages[3],rt);
 if(auto shader=read<void*>(state,0x38))commit(context,shader,Stages[1],rt);
 if(auto shader=read<void*>(state,0x40))commit(context,shader,Stages[2],rt);
 if(auto shader=read<void*>(state,0x48))commit(context,shader,Stages[4],rt);
}
}
