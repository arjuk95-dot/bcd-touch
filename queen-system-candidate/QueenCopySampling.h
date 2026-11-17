#pragma once
#include <algorithm>
#include <atomic>
#include <cstdint>
#include <string>

// Private FEX storage. NOT exported to or interpreted by the native Wine donor.
// Module.S owns increments. Every field accessed concurrently is naturally
// aligned and read with atomic builtins. Configuration freezes before ThreadInit.
extern "C" {
alignas(64) uint64_t QueenCopyConfig[8] {}; // copy body/FFS,set body/FFS,enabled
alignas(64) uint64_t QueenCopySeen {};
alignas(64) uint64_t QueenCopyDropped {};
alignas(2048) uint64_t QueenCopyRows[256][256] {};
}
static_assert(sizeof(QueenCopyRows[0])==2048);

static void InstallQueenCopySampling() {
  if(!IosEcExitLean){LogMan::Msg::EFmt("[queen-copy] disabled: lean JIT exit unavailable");return;}
  auto handle=GetModuleHandleA("ucrtbase.dll");
  if(!handle)return;
  const uintptr_t base=IosJitReverseTranslate(reinterpret_cast<uintptr_t>(handle));
  uint32_t nt=0,stamp=0,size=0;
  if(!queen_self_export::ReadMapped(base+0x3c,&nt,4)||nt<0x40||nt>0x100000||
     !queen_self_export::ReadMapped(base+nt+8,&stamp,4)||stamp!=0x69efb235||
     !queen_self_export::ReadMapped(base+nt+24+56,&size,4)||size!=0x130000)return;
  const auto copy=queen_self_export::Resolve(base,base+0x61610,"memcpy");
  const auto set=queen_self_export::Resolve(base,base+0x62e08,"memset");
  if(copy.image!=base||set.image!=base||copy.native!=base+0x61610||set.native!=base+0x62e08)return;
  QueenCopyConfig[0]=copy.native;QueenCopyConfig[1]=copy.ffs;
  QueenCopyConfig[2]=set.native;QueenCopyConfig[3]=set.ffs;
  __atomic_store_n(&QueenCopyConfig[4],uint64_t{1},__ATOMIC_RELEASE);
  LogMan::Msg::EFmt("[queen-copy] v1 enabled sampled-exit-only; targets copy={:#x}/{:#x} set={:#x}/{:#x}; bins0=zero, binN=[2^(N-1),2^N-1]; counts are1/64 observations, not exact calls",copy.native,copy.ffs,set.native,set.ffs);
}

extern "C" void QueenCopyReport() {
  if(!__atomic_load_n(&QueenCopyConfig[4],__ATOMIC_ACQUIRE))return;
  // A cheap ticket gate avoids a clock call on every compilation. Existing
  // transition ring index is READ ONLY; its layout and ownership are unchanged.
  static std::atomic<uint64_t> lastProbe {0};
  const auto ticket=__atomic_load_n(&IosXpFex[3136/8],__ATOMIC_RELAXED);
  auto prior=lastProbe.load(std::memory_order_relaxed);
  if(ticket-prior<16384||!lastProbe.compare_exchange_strong(prior,ticket,std::memory_order_relaxed))return;
  static std::atomic_flag reporting=ATOMIC_FLAG_INIT;
  if(reporting.test_and_set(std::memory_order_acquire))return;
  struct Unlock { ~Unlock(){reporting.clear(std::memory_order_release);} } unlock;
  static uint64_t lastMs=0,lastSeen=0,lastDropped=0;
  const auto now=static_cast<uint64_t>(GetTickCount64());
  if(lastMs && now-lastMs<1000)return;
  const auto elapsed=lastMs?now-lastMs:0;lastMs=now;
  static uint64_t previous[256][2][65] {};
  static uint64_t previousBytes[256][2] {};
  struct Candidate { uint64_t frame,tid,count,bytes,overflow,bins[65]; unsigned api; };
  // Static, lock-protected scratch: do not put ~280KB on FEX's256KB stack.
  static Candidate candidates[512];
  unsigned count=0;uint64_t accepted=0;
  for(unsigned row=0;row<256;++row) {
    const auto frame=__atomic_load_n(&QueenCopyRows[row][0],__ATOMIC_ACQUIRE);
    const auto tid=__atomic_load_n(&QueenCopyRows[row][1],__ATOMIC_ACQUIRE);
    if(!frame||!tid)continue;
    for(unsigned api=0;api<2;++api) {
      auto& c=candidates[count];c={};c.frame=frame;c.tid=tid;c.api=api;
      for(unsigned bin=0;bin<65;++bin) {
        const auto v=__atomic_load_n(&QueenCopyRows[row][2+65*api+bin],__ATOMIC_RELAXED);
        c.bins[bin]=v-previous[row][api][bin];previous[row][api][bin]=v;c.count+=c.bins[bin];
      }
      const auto bytes=__atomic_load_n(&QueenCopyRows[row][132+api],__ATOMIC_RELAXED);
      c.bytes=bytes-previousBytes[row][api];previousBytes[row][api]=bytes;
      c.overflow=__atomic_load_n(&QueenCopyRows[row][134+api],__ATOMIC_RELAXED);
      accepted+=c.count;if(c.count)++count;
    }
  }
  const auto seen=__atomic_load_n(&QueenCopySeen,__ATOMIC_RELAXED);
  const auto dropped=__atomic_load_n(&QueenCopyDropped,__ATOMIC_RELAXED);
  if(!accepted && seen==lastSeen && dropped==lastDropped)return;
  LogMan::Msg::EFmt("[queen-copy] v1 window_ms={} initial_cumulative={} observed={} accepted={} dropped={} active_thread_api_rows={} (atomic snapshot, not simultaneous)",elapsed,elapsed==0,seen-lastSeen,accepted,dropped-lastDropped,count);
  lastSeen=seen;lastDropped=dropped;
  const auto shown=std::min(count,4u);
  std::partial_sort(candidates,candidates+shown,candidates+count,[](const Candidate&a,const Candidate&b){return a.count>b.count;});
  for(unsigned i=0;i<shown;++i) {
    const auto& c=candidates[i];std::string bins;
    for(unsigned b=0;b<65;++b)if(c.bins[b]){if(!bins.empty())bins+=",";bins+=std::to_string(b)+":"+std::to_string(c.bins[b]);}
    LogMan::Msg::EFmt("[queen-copy] tid={:#x} frame={:#x} api={} sampled_entries={} sampled_bytes={} bytes_invalid={} bins={}",c.tid,c.frame,c.api?"memset":"memcpy",c.count,c.bytes,c.overflow!=0,bins);
  }
}
