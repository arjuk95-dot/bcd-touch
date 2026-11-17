#pragma once
#include "QueenBoundShaderState.h"
#if defined(_MSC_VER) && !defined(__clang__)
#include <intrin.h>
#endif
// ARM64EC-only production boundary candidate, not registered. The caller must
// supply actual guest image base and IOSLoadTEB(), after byte/version validation.
// Calling these pointers from plain Apple ARM64 is NOT a supported guest bridge.
struct QueenBoundShaderRuntime {
  unsigned char* base;
  void* teb;
  void* imageBase() {return base;}
  void* guestTEB() {return teb;}
  template<class Fn> Fn guest(uintptr_t rva) {return reinterpret_cast<Fn>(base+rva);}
  bool flagLock() {return *reinterpret_cast<volatile uint8_t*>(base+0x4b43741)!=0;}
  bool flagDeferred() {return *reinterpret_cast<volatile uint8_t*>(base+0x4b536a4)!=0;}
  uint32_t atomicAdd32(void* p,uintptr_t offset,uint32_t delta) {
    auto address=reinterpret_cast<uint32_t*>(static_cast<unsigned char*>(p)+offset);
#if defined(_MSC_VER) && !defined(__clang__)
    return static_cast<uint32_t>(_InterlockedExchangeAdd(reinterpret_cast<volatile long*>(address),static_cast<long>(delta)));
#else
    return __atomic_fetch_add(address,delta,__ATOMIC_SEQ_CST);
#endif
  }
  uint32_t atomicCas32(void* p,uintptr_t offset,uint32_t expected,uint32_t desired) {
    auto address=reinterpret_cast<uint32_t*>(static_cast<unsigned char*>(p)+offset);
#if defined(_MSC_VER) && !defined(__clang__)
    return static_cast<uint32_t>(_InterlockedCompareExchange(reinterpret_cast<volatile long*>(address),static_cast<long>(desired),static_cast<long>(expected)));
#else
    __atomic_compare_exchange_n(address,&expected,desired,false,__ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST);
    return expected;
#endif
  }
  bool mayDeleteNow() {return guest<uint8_t(*)()>(0x776410)()!=0;}
  void deferDelete(void* p) {guest<void(*)(void*,void*)>(0x7d6a00)(base+0x4b46708,p);}
  void deleteResource(void* p) {
    auto table=QueenBoundShader::read<void*>(p,0);
    auto entry=QueenBoundShader::read<void*>(table,0);
    reinterpret_cast<void(*)(void*,uint32_t)>(entry)(p,1);
  }
  void shaderBind(void* context,uintptr_t offset,void* shader,bool classes) {
    auto table=QueenBoundShader::read<void*>(context,0);
    auto entry=QueenBoundShader::read<void*>(table,offset);
    if(classes) reinterpret_cast<void(*)(void*,void*,void*,uint32_t)>(entry)(context,shader,nullptr,0);
    else reinterpret_cast<void(*)(void*,void*)>(entry)(context,shader);
  }
  void enterHistory(void* p) {
    auto entry=QueenBoundShader::read<void*>(base,0x373b770);
    reinterpret_cast<void(*)(void*)>(entry)(p);
  }
  void leaveHistory(void* p) {
    auto entry=QueenBoundShader::read<void*>(base,0x373b778);
    reinterpret_cast<void(*)(void*)>(entry)(p);
  }
  void initHeader(int32_t* guard) {guest<void(*)(int32_t*)>(0x36af1d4)(guard);}
  void initFooter(int32_t* guard) {guest<void(*)(int32_t*)>(0x36af174)(guard);}
  uint8_t initFlag() {return guest<uint8_t(*)()>(0x143f6f0)();}
  void conditionalCommit(void* adjustedContext) {guest<void(*)(void*)>(0x1437f70)(adjustedContext);}
};
