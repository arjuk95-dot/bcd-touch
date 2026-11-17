#pragma once
#include <FEXCore/Core/QueenGuestLeaf.h>
#include "QueenGuestLeafBytes.h"
#include "QueenGuestLeafFingerprint.h"
namespace queen_guest_leaf {
static bool IsReadableNonEcGuest(uintptr_t guest) {
  // Exact dispatcher bitmap bound from Arm64Emitter.h; keep private emitter
  // headers out of the Windows module. Reject unusual/unreadable mappings.
  if(guest >= (uint64_t{1} << 47) || !IosEcCodeBitMapValue)return false;
  const uintptr_t word=IosEcCodeBitMapValue+(guest>>18)*sizeof(uint64_t);
  uint64_t bits=0;
  return queen_self_export::ReadMapped(word,&bits,sizeof(bits)) &&
         !(bits & (uint64_t{1} << ((guest>>12)&63)));
}
template<size_t N>
static queen_self_export::Result Verify(const char* module,const char* api,uint32_t stamp,uint32_t size,uint32_t rva,const char (&hash)[65]) {
  auto handle=GetModuleHandle(module);
  if(!handle)return {};
  const uintptr_t base=IosJitReverseTranslate(reinterpret_cast<uintptr_t>(handle));
  uint32_t nt=0,actualStamp=0,actualSize=0;
  if(!queen_self_export::ReadMapped(base+0x3c,&nt,4)||nt<0x40||nt>0x100000||
     !queen_self_export::ReadMapped(base+nt+8,&actualStamp,4)||actualStamp!=stamp||
     !queen_self_export::ReadMapped(base+nt+24+56,&actualSize,4)||actualSize!=size)return {};
  // This reads the ORIGINAL PE, not its executable JIT alias. The loader's
  // x18 rewriting changes only the alias; the raw original body stays pinned.
  uint8_t current[N];
  if(!queen_self_export::ReadMapped(base+rva,current,N)||!queen_fingerprint_hash::Matches(current,N,hash))return {};
  auto result=queen_self_export::Resolve(base,base+rva,api);
  if(result.image!=base||result.native!=base+rva)return {};
  return result;
}
}
static void InstallQueenGuestLeaf(void* mainModule) {
  const char* enabled=getenv("BCD_QUEEN_NATIVE_NAV");
  if(!enabled||strcmp(enabled,"1")||!CTX||!mainModule)return;
  const uintptr_t game=reinterpret_cast<uintptr_t>(mainModule);
  const auto path=FEX::Windows::GetSectionFilePath(game);
  const auto name=FEX::Windows::BaseName(path);
  constexpr const char expected[]="queensdomain-win64-shipping.exe";
  if(name.size()!=sizeof(expected)-1)return;
  for(size_t i=0;i<name.size();++i){const char c=name[i]>='A'&&name[i]<='Z'?name[i]+('a'-'A'):name[i];if(c!=expected[i])return;}
  if(!queen_nav662::MatchesImage(game))return;
  using namespace queen_guest_leaf;
  const auto tls=Verify<TlsBodySize>("kernelbase.dll","TlsGetValue",TlsTimestamp,TlsImageSize,TlsBodyRva,TlsBodyHash);
  const auto tid=Verify<ThreadIdBodySize>("kernel32.dll","GetCurrentThreadId",ThreadIdTimestamp,ThreadIdImageSize,ThreadIdBodyRva,ThreadIdBodyHash);
  if(!tls.ffs||!tid.ffs){LogMan::Msg::EFmt("[queen-leaf] module/body validation failed; native paths retained");return;}
  constexpr size_t pageSize=FEXCore::Utils::FEX_PAGE_SIZE;
  auto page=static_cast<uint8_t*>(::VirtualAlloc(nullptr,pageSize,MEM_COMMIT|MEM_TOP_DOWN,PAGE_EXECUTE_READWRITE));
  if(!page){LogMan::Msg::EFmt("[queen-leaf] guest page allocation failed; native paths retained");return;}
  // Same guest-code allocation/notification contract as X64ReturnInstr.
  const uintptr_t tlsGuest=reinterpret_cast<uintptr_t>(page), tidGuest=tlsGuest+128;
  if(!IsReadableNonEcGuest(tlsGuest)||!IsReadableNonEcGuest(tidGuest)){
    ::VirtualFree(page,0,MEM_RELEASE);
    LogMan::Msg::EFmt("[queen-leaf] surrogate page unexpectedly EC; native paths retained");return;
  }
  std::memcpy(page,queen_guest_leaf::TlsGetValue,sizeof(queen_guest_leaf::TlsGetValue));
  std::memcpy(page+128,queen_guest_leaf::GetCurrentThreadId,sizeof(queen_guest_leaf::GetCurrentThreadId));
  // Preflight the immutable exact-tag slots before publishing any mapping.
  const uint64_t targets[]={tls.ffs,tls.native,tid.ffs,tid.native};
  const uint64_t guests[]={tlsGuest,tlsGuest,tidGuest,tidGuest};
  for(size_t i=0;i<4;++i){
    auto &slot=FEXCore::Core::QueenGuestLeafTargets[(targets[i]>>3)&63];
    if(slot.Native){::VirtualFree(page,0,MEM_RELEASE);return;}
    for(size_t j=0;j<i;++j)if(((targets[i]>>3)&63)==((targets[j]>>3)&63)){
      ::VirtualFree(page,0,MEM_RELEASE);
      LogMan::Msg::EFmt("[queen-leaf] table collision; native paths retained");return;
    }
  }
  InvalidationTracker->HandleMemoryProtectionNotification(tlsGuest,pageSize,PAGE_EXECUTE_READ);
  for(size_t i=0;i<4;++i)FEXCore::Core::QueenGuestLeafRegister(targets[i],guests[i]);
  // Process-lifetime page/table. No mutation or unload after guest ThreadInit.
  LogMan::Msg::EFmt("[queen-leaf] registered full-contract guest TLS {:#x}/{:#x}->{:#x}, thread-id {:#x}/{:#x}->{:#x}; original native APIs unchanged",tls.ffs,tls.native,tlsGuest,tid.ffs,tid.native,tidGuest);
}
