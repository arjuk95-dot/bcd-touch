#pragma once
// Candidate: host differential cases validated; ARM/device gates remain.
// Five graphics-stage resource committers of exact Queen 1.01.03.
// Context is full D3D11RHI context, NOT the +0x18 interface passed to bound setter.
#include <cstdint>
#include <cstring>
namespace QueenStageCommit {
struct Layout {
 uint32_t entry, dirty, uniform, texture, maxTexture, srv, sampler, bindSrv, bindSampler;
};
inline constexpr Layout Stages[] = {
 {0x1432240,0x43c8,0x4128,0x27e8,0x40f0,0x198,0x1dc8,0xc8,0xd0}, // VS
 {0x14319a0,0x43ca,0x4198,0x2be8,0x40f4,0x598,0x1e48,0x1d8,0x1e8}, // HS
 {0x1431100,0x43cc,0x4208,0x2fe8,0x40f8,0x998,0x1ec8,0x1f8,0x208}, // DS
 {0x1431df0,0x43ce,0x4278,0x33e8,0x40fc,0xd98,0x1f48,0x40,0x50}, // PS
 {0x1431550,0x43d0,0x42e8,0x37e8,0x4100,0x1198,0x1fc8,0xf8,0x100} // GS
};
template<class T> T read(const void* p, uintptr_t o) {
 T value; std::memcpy(&value, static_cast<const uint8_t*>(p)+o,sizeof(value)); return value;
}
template<class T> void write(void* p,uintptr_t o,T v) {
 std::memcpy(static_cast<uint8_t*>(p)+o,&v,sizeof(v));
}
// Services must preserve callback order, exceptions and mutable rereads.
// missingUniform/Texture/View reproduce ORIGINAL assertion callbacks; not no-op.
// textureStamp(): original shared double -> float per UB, returned as raw bits.
// expandTextureStamp(): float -> double only for nonempty texture table.
// touchTexture(): original UCOMISD / JE behavior (unordered also skips write),
// matching audited FEX FP semantics (AFP-off). Do not use != for NaNs.
// resolveTexture(): original resource virtual slot0x48, possibly guest code.
// addRef/release(): original native COM vtable slots8/16, not game resource refs.
// bind(): same native context/slot/one element call; not delayed or reordered.
// observe(): optional bounded, thread-owned counters; MUST NOT call game code.
// Events0=commit,1=dirty UB,2=texture table entry,3=SRV entry,4=sampler entry,
// 5=changed SRV,6=changed sampler,7=texture resolve. No performance assertion.
template<class Runtime> void pair(void* context,const Layout& s,unsigned slot,
                                   void* texture,void* view,Runtime& rt) {
 // Exactly one null is a deliberate no-op in shipped code; preserve it.
 if ((texture==nullptr)!=(view==nullptr)) return;
 const uintptr_t index=uintptr_t(slot)*8;
 if(texture) {
  const int32_t old=read<int32_t>(context,s.maxTexture);
  write<int32_t>(context,s.maxTexture,old>=int32_t(slot)?old:int32_t(slot));
  write<void*>(context,s.texture+index,texture);
 } else if(read<void*>(context,s.texture+index)) {
  write<void*>(context,s.texture+index,nullptr);
  int32_t highest=read<int32_t>(context,s.maxTexture);
  if(highest==int32_t(slot)) {
   do { --highest; write<int32_t>(context,s.maxTexture,highest); }
   while(highest>=0 && read<void*>(context,s.texture+uintptr_t(highest)*8)==nullptr);
  }
 }
 void* old=read<void*>(context,s.srv+index);
 if(old==view)return;
 if(view) {
  rt.addRef(view);
  // Callback can alter cache; original rereads after AddRef.
  old=read<void*>(context,s.srv+index);
 }
 if(old) rt.release(old);
 write<void*>(context,s.srv+index,view);
 rt.observe(s.entry,5,1);
 rt.bind(read<void*>(context,0x190),s.bindSrv,slot,view);
}
template<class F> bool table(void* shader,uintptr_t offset,unsigned uniformSlot,F&& fn) {
 auto entries=read<const uint32_t*>(shader,offset);
 const uint32_t start=read<uint32_t>(entries,uintptr_t(uniformSlot)*4);
 if(!start)return false;
 uintptr_t cursor=uintptr_t(start)*4;
 uint32_t encoded=read<uint32_t>(entries,cursor); cursor+=4;
 // Shipped code trusts the first token's UB field, tests following sentinel only.
 do { fn(encoded); encoded=read<uint32_t>(entries,cursor); cursor+=4; }
 while((encoded>>24)==uniformSlot);
 return true;
}
template<class Runtime> void commit(void* context,void* shader,const Layout& s,Runtime& rt) {
 rt.observe(s.entry,0,1);
 uint32_t mask=read<uint16_t>(context,s.dirty)&read<uint32_t>(shader,0x30);
 while(mask) {
  unsigned ub=0; while(((mask>>ub)&1u)==0)++ub;
  mask^=uint32_t(1)<<ub;
  auto uniform=read<void*>(context,s.uniform+uintptr_t(ub)*8);
  if(!uniform)rt.missingUniform(s.entry,ub);
  rt.observe(s.entry,1,1);
  auto resources=read<void*>(uniform,0x48);
  const uint64_t rawStamp=rt.textureStamp();
  uint64_t stamp=0;bool expanded=false;
  bool nonempty=table(shader,0x78,ub,[&](uint32_t encoded){
   if(!expanded){stamp=rt.expandTextureStamp(rawStamp);expanded=true;}
   const unsigned ri=(encoded>>8)&0xffff, slot=encoded&0xff;
   auto texture=read<void*>(resources,uintptr_t(ri)*8);
   if(!texture)rt.missingTexture(s.entry,ri,slot,ub);
   rt.observe(s.entry,2,1);
   rt.touchTexture(texture,stamp);
   rt.observe(s.entry,7,1);
   auto resolved=rt.resolveTexture(texture);
   const auto base=read<void*>(resolved,0x20), view=read<void*>(resolved,0x30);
   pair(context,s,slot,base,view,rt);
  });
  // Match conditional reread after callbacks, not before an empty table.
  if(nonempty)resources=read<void*>(uniform,0x48);
  nonempty=table(shader,0x38,ub,[&](uint32_t encoded){
   const unsigned ri=(encoded>>8)&0xffff, slot=encoded&0xff;
   auto view=read<void*>(resources,uintptr_t(ri)*8);
   if(!view)rt.missingView(s.entry,ri,slot,ub);
   rt.observe(s.entry,3,1);
   pair(context,s,slot,read<void*>(view,0x20),read<void*>(view,0x18),rt);
  });
  if(nonempty)resources=read<void*>(uniform,0x48);
  table(shader,0x48,ub,[&](uint32_t encoded){
   const unsigned ri=(encoded>>8)&0xffff, slot=encoded&0xff;
   auto sampler=read<void*>(resources,uintptr_t(ri)*8);
   auto native=read<void*>(sampler,0x18);
   rt.observe(s.entry,4,1);
   if(read<void*>(context,s.sampler+uintptr_t(slot)*8)!=native) {
    write<void*>(context,s.sampler+uintptr_t(slot)*8,native);
    rt.observe(s.entry,6,1);
    rt.bind(read<void*>(context,0x190),s.bindSampler,slot,native);
   }
  });
 }
 // Clear the WHOLE mask even if shader resource mask excluded some dirty bits.
 write<uint16_t>(context,s.dirty,0);
}
}


