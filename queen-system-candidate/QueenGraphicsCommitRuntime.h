#pragma once
#include "QueenGraphicsCommit.h"
#include "QueenGraphicsGuestFp.h"
#if defined(__clang__) && (defined(__aarch64__) || defined(__arm64ec__) || defined(_M_ARM64EC))
#include <arm_neon.h>
#define QUEEN_GRAPHICS_NATIVE_FP 1
#endif
// Compile in the ARM64EC PE runtime, NOT plain Apple ARM64. Typed calls use the
// compiler's existing x64/EC boundary support. Native FP requires AFP disabled.
// Native uses the exact FEX FCVTN/FCVTL/FCMP operations and current FPCR; no
// per-texture guest crossings or synthetic MXCSR exception updates.
struct QueenGraphicsCommitRuntime {
 unsigned char* base;
 template<class Fn> Fn guest(uintptr_t rva){return reinterpret_cast<Fn>(base+rva);}
 template<class T> static T load(const void* p,uintptr_t o){return QueenStageCommit::read<T>(p,o);}
 void observe(uint32_t,unsigned,unsigned){} // Integrator may use per-call counters.
 void missingUniform(uint32_t,unsigned ub){
  guest<void(*)(const char*,uint32_t,const wchar_t*,...)>(0xf2f040)(
   reinterpret_cast<const char*>(base+0x376a598),0x5ee,reinterpret_cast<const wchar_t*>(base+0x3a0e3b0),uint32_t(ub));
  guest<void(*)()>(0xf32880)();
 }
 void missingTexture(uint32_t,unsigned ri,unsigned bind,unsigned){
  guest<void(*)(const char*,uint32_t,const wchar_t*,...)>(0xf2f040)(
   reinterpret_cast<const char*>(base+0x376a598),0x548,reinterpret_cast<const wchar_t*>(base+0x3a0e670),
   uint32_t(ri),uint32_t(bind),static_cast<const wchar_t*>(nullptr));
  guest<void(*)()>(0xf32880)();
 }
 void missingView(uint32_t,unsigned ri,unsigned bind,unsigned){
  guest<void(*)(const char*,uint32_t,const wchar_t*,...)>(0xf2f040)(
   reinterpret_cast<const char*>(base+0x376a598),0x5a4,reinterpret_cast<const wchar_t*>(base+0x3a0e6e0),
   uint32_t(ri),uint32_t(bind),static_cast<const wchar_t*>(nullptr));
  guest<void(*)()>(0xf32880)();
 }
 static bool FpReady(bool hostSupportsAFP){
#ifdef QUEEN_GRAPHICS_NATIVE_FP
  return !hostSupportsAFP;
#else
  return !hostSupportsAFP&&QueenGraphicsGuestFp::Ready(); // Host oracle only.
#endif
 }
 uint64_t textureStamp(){
#ifdef QUEEN_GRAPHICS_NATIVE_FP
  uint64x2_t bits={*reinterpret_cast<volatile uint64_t*>(base+0x49d5720),0};
  float64x2_t source=vreinterpretq_f64_u64(bits);float32x2_t narrowed;
  __asm__ volatile("fcvtn %0.2s, %1.2d" : "=w"(narrowed) : "w"(source));
  return vget_lane_u32(vreinterpret_u32_f32(narrowed),0);
#else
  uint32_t bits=0;QueenGraphicsGuestFp::Narrow(base+0x49d5720,&bits);return bits;
#endif
 }
 uint64_t expandTextureStamp(uint64_t raw){
#ifdef QUEEN_GRAPHICS_NATIVE_FP
  uint32x2_t bits={uint32_t(raw),0};float32x2_t source=vreinterpret_f32_u32(bits);float64x2_t expanded;
  __asm__ volatile("fcvtl %0.2d, %1.2s" : "=w"(expanded) : "w"(source));
  return vgetq_lane_u64(vreinterpretq_u64_f64(expanded),0);
#else
  uint32_t bits=uint32_t(raw);uint64_t result=0;QueenGraphicsGuestFp::Expand(&bits,&result);return result;
#endif
 }
 void touchTexture(void* texture,uint64_t stamp){
  auto destination=load<void*>(texture,0x48);
#ifdef QUEEN_GRAPHICS_NATIVE_FP
  double a;std::memcpy(&a,&stamp,8);const double b=load<double>(destination,0);
  uint32_t equal,unordered;
  __asm__ volatile("fcmp %d2, %d3\n\tcset %w0, eq\n\tcset %w1, vs"
                   : "=&r"(equal),"=&r"(unordered) : "w"(a),"w"(b) : "cc");
  if(!(equal|unordered))QueenStageCommit::write<uint64_t>(destination,0,stamp);
#else
  QueenGraphicsGuestFp::Touch(destination,&stamp);
#endif
 } void* resolveTexture(void* p){
  auto v=load<void*>(p,0);auto f=load<void*>(v,0x48);return reinterpret_cast<void*(*)(void*)>(f)(p);
 }
 void addRef(void* p){auto v=load<void*>(p,0);reinterpret_cast<uint32_t(*)(void*)>(load<void*>(v,8))(p);}
 void release(void* p){auto v=load<void*>(p,0);reinterpret_cast<uint32_t(*)(void*)>(load<void*>(v,0x10))(p);}
 void bind(void* p,uintptr_t slot,unsigned index,void* view){
  auto v=load<void*>(p,0);reinterpret_cast<void(*)(void*,uint32_t,uint32_t,void*const*)>(load<void*>(v,slot))(p,index,1,&view);
 }
 bool uavGrowthFastPathEnabled(){return *reinterpret_cast<volatile int32_t*>(base+0x474f6fc)!=0;}
 void* emptyResourceTable(){return base+0x376a540;}
 void resetPixelUav(void* c,bool v){guest<void(*)(void*,bool)>(0x14393e0)(c,v);}
 uint32_t commitPixelUav(void* c,void* a,void* u,void* t,unsigned i,const void* e){
  return guest<uint32_t(*)(void*,void*,void*,void*,unsigned,const void*)>(0x1432690)(c,a,u,t,i,e);
 }
 void flushPixelUav(void* c){guest<void(*)(void*)>(0x14395d0)(c);}
};


