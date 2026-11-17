#pragma once
// Semantic native-island prototype for exact Queen RVA1453cf0..145401e.
// NOT registered or production ready. Runtime must supply reviewed ARM64EC
// callback/atomic/TLS services, preserving the contracts below.
#include <cstdint>
#include <cstring>
namespace QueenBoundShader {
template<class T> inline T read(const void* p,uintptr_t offset) {
  T v;std::memcpy(&v,static_cast<const unsigned char*>(p)+offset,sizeof(v));return v;
}
template<class T> inline void write(void* p,uintptr_t offset,T v) {
  std::memcpy(static_cast<unsigned char*>(p)+offset,&v,sizeof(v));
}

// Runtime requirements (not optional no-op hooks):
// shaderBind(nativeContext,slot,newShader,hasClassArray): invoke mixed ABI vtable.
// atomicAdd32(object,offset,delta): LOCK XADD semantics; return OLD uint32 value.
// atomicCas32(object,offset,expected,desired): LOCK CMPXCHG; return OLD uint32.
// flagLock/flagDeferred(): fresh volatile reads of respective exact game globals.
// mayDeleteNow(): original guest function RVA776410 returning low-byte bool.
// deferDelete(object): original guest function RVA7d6a00(queueGlobal, object).
// deleteResource(object): guest virtual destructor slot0(object,1).
// enterHistory/leaveHistory(ptr): original imported critical-section calls.
// finish(context): use finish() below with the same guest TEB, never implicit
// native C++ TLS. It preserves FULL original TLS guard and conditional behavior.
// See render-functions.json for all addresses. finish is deliberately mandatory;
// it is NOT simply a call to1437f70 and must not be stubbed in production.
template<class Runtime> inline void release(void* resource,Runtime& rt) {
  if (!resource) return;
  if (rt.atomicAdd32(resource,8,0xffffffffu)!=1) return;
  if (read<uint8_t>(resource,0x10)!=0) {rt.deleteResource(resource);return;}
  if (!rt.flagDeferred() && rt.mayDeleteNow()) {rt.deleteResource(resource);return;}
  if (rt.atomicCas32(resource,0xc,0,1)==0) rt.deferDelete(resource);
}

// Additional services: imageBase() is the actual mapped PE base; guestTEB()
// is the x64 guest TEB whose GS base the translated function uses; initHeader
// and initFooter call exact guest36af1d4/36af174; initFlag calls143f6f0;
// conditionalCommit calls1437f70 with adjusted context. Callbacks must retain
// original current-thread exception/TLS behavior and propagate failures.
template<class Runtime> inline void finish(void* context,Runtime& rt) {
  auto base=static_cast<unsigned char*>(rt.imageBase());
  auto tls=read<void*>(rt.guestTEB(),0x58);
  const auto tlsIndex=read<uint32_t>(base,0x4c06368);
  auto slot=read<void*>(tls,uintptr_t(tlsIndex)*8);
  const auto epoch=read<int32_t>(slot,0x108);
  auto guard=reinterpret_cast<volatile int32_t*>(base+0x4a73e9c);
  if(*guard>epoch) {
    rt.initHeader(const_cast<int32_t*>(guard));
    if(*guard==-1) {
      const uint8_t flag=rt.initFlag();
      *reinterpret_cast<volatile uint8_t*>(base+0x4a73e98)=flag;
      rt.initFooter(const_cast<int32_t*>(guard));
    }
  }
  if(*reinterpret_cast<volatile int32_t*>(base+0x4a73608)!=0 ||
     *reinterpret_cast<volatile uint8_t*>(base+0x4a73e98)!=0)
    rt.conditionalCommit(static_cast<unsigned char*>(context)-0x18);
}

template<class Runtime> inline void set(void* context,void* state,Runtime& rt) {
  // Preserve ordering of initial copies before any native method call.
  unsigned char a[16],b[16];
  std::memcpy(a,static_cast<unsigned char*>(state)+0x58,16);
  std::memcpy(static_cast<unsigned char*>(context)+0x1d90,a,16);
  std::memcpy(b,static_cast<unsigned char*>(state)+0x68,16);
  std::memcpy(static_cast<unsigned char*>(context)+0x1da0,b,16);
  struct Binding {uintptr_t source,cache,slot;bool classes;};
  static constexpr Binding bindings[]={
    {0x78,0x1d88,0x88,false},{0x80,0x1998,0x58,true},
    {0x88,0x19b8,0x48,true},{0x90,0x19a0,0x1e0,true},
    {0x98,0x19a8,0x200,true},{0xa0,0x19b0,0xb8,true}};
  for (const auto& binding:bindings) {
    auto shader=read<void*>(state,binding.source);
    if(read<void*>(context,binding.cache)!=shader) {
      write(context,binding.cache,shader);
      // Re-read after prior callback, as shipped code does.
      auto device=read<void*>(context,0x178);
      rt.shaderBind(device,binding.slot,shader,binding.classes);
    }
  }
  write<uint8_t>(context,0x43d5,read<void*>(state,0x90)!=nullptr && read<void*>(state,0x98)!=nullptr);
  write<uint8_t>(context,0x43d4,1);
  if(rt.flagLock()) rt.enterHistory(static_cast<unsigned char*>(context)+0x17cd0);
  const auto index=read<uint32_t>(context,0x17cc8);
  auto previous=read<void*>(context,0x4448+uintptr_t(index)*8);
  write(context,0x4448+uintptr_t(index)*8,state);
  rt.atomicAdd32(state,8,1);
  release(previous,rt);
  // Re-read index after release callbacks; do not reuse the saved index.
  const uint32_t next=read<uint32_t>(context,0x17cc8)+1u;
  write<uint32_t>(context,0x17cc8,next%10000u);
  // Original independently rechecks the flag rather than retaining first read.
  if(rt.flagLock()) rt.leaveHistory(static_cast<unsigned char*>(context)+0x17cd0);
  write<uint64_t>(context,0x43b0,UINT64_MAX);
  write<uint16_t>(context,0x43b8,UINT16_MAX);
  for(uintptr_t i=0;i<84;i++) {
    auto resource=read<void*>(context,0x4110+i*8);
    write<void*>(context,0x4110+i*8,nullptr);
    release(resource,rt);
  }
  finish(context,rt);
}
}
