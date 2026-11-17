#pragma once
// Startup-only lookup. Keep the compiler's exported x64 FFS, not a raw ARM body.
#include <cstdint>
#include <cstddef>
#include <cstring>
namespace queen_self_export {
struct Result {uintptr_t image=0, ffs=0, native=0;};
// Read must copy only readable mapped bytes and reject all out-of-range reads.
template<class Read> Result Find(uintptr_t base,size_t mappedExtent,const char* wanted,Read read) {
  Result fail{};
  auto get=[&](size_t offset,void* out,size_t size) {
    return offset<=mappedExtent && size<=mappedExtent-offset && read(base+offset,out,size);
  };
  uint16_t mz=0;uint32_t nt=0,sig=0,imageSize=0;uint16_t machine=0,optionalSize=0,magic=0,sections=0;
  if(!get(0,&mz,2)||mz!=0x5a4d||!get(0x3c,&nt,4)||nt<0x40||nt>0x100000)return fail;
  if(!get(nt,&sig,4)||sig!=0x4550||!get(nt+4,&machine,2)||machine!=0x8664||
     !get(nt+6,&sections,2)||!sections||sections>96||!get(nt+20,&optionalSize,2)||optionalSize<120||
     !get(nt+24,&magic,2)||magic!=0x20b||!get(nt+24+56,&imageSize,4)||imageSize>mappedExtent)return fail;
  mappedExtent=imageSize;
  uint32_t directoryCount=0,exportRva=0,exportSize=0;
  if(!get(nt+24+108,&directoryCount,4)||!directoryCount||
     !get(nt+24+112,&exportRva,4)||!get(nt+24+116,&exportSize,4)||
     exportSize<40||exportRva>imageSize||exportSize>imageSize-exportRva)return fail;
  uint32_t count=0,names=0,functions=0,nameArray=0,ordinals=0;
  if(!get(exportRva+20,&count,4)||!get(exportRva+24,&names,4)||names>65536||count>65536||
     !get(exportRva+28,&functions,4)||!get(exportRva+32,&nameArray,4)||!get(exportRva+36,&ordinals,4))return fail;
  const size_t wantedSize=std::strlen(wanted)+1;if(wantedSize>128)return fail;
  uint32_t entry=0;
  for(uint32_t i=0;i<names;i++) {
    uint32_t name=0;uint16_t ordinal=0;char text[128]{};
    if(!get(size_t(nameArray)+i*4,&name,4))return fail;
    if(!get(name,text,wantedSize))return fail;
    if(std::memcmp(text,wanted,wantedSize))continue;
    if(!get(size_t(ordinals)+i*2,&ordinal,2)||ordinal>=count||!get(size_t(functions)+ordinal*4,&entry,4))return fail;
    break;
  }
  if(!entry||(entry>=exportRva&&entry-exportRva<exportSize))return fail; // No export forwarding strings.
  uint8_t ffs[14]{};
  static constexpr uint8_t prefix[]={0x48,0x8b,0xc4,0x48,0x89,0x58,0x20,0x55,0x5d,0xe9};
  if(!get(entry,ffs,14)||std::memcmp(ffs,prefix,10))return fail;
  int32_t displacement=0;std::memcpy(&displacement,ffs+10,4);
  const int64_t target=int64_t(entry)+14+displacement;
  if(target<4||target>=imageSize)return fail;
  auto executable=[&](uint32_t rva,size_t size) {
    for(uint16_t i=0;i<sections;i++) {
      const size_t section=size_t(nt)+24+optionalSize+size_t(i)*40;
      uint32_t va=0,vs=0,raw=0,flags=0;
      if(!get(section+8,&vs,4)||!get(section+12,&va,4)||!get(section+16,&raw,4)||!get(section+36,&flags,4))return false;
      const uint32_t length=vs>raw?vs:raw;
      if((flags&0x20000000)&&rva>=va&&rva-va<length&&size<=length-(rva-va))return true;
    }
    return false;
  };
  if(!executable(entry,14)||!executable(uint32_t(target),4))return fail;
  // Validate actual loaded CHPE code-kind too: FFS=x64, target=ARM64EC.
  uint32_t configRva=0,configSize=0,mapRva=0,mapCount=0;uint64_t metadata=0;
  if(directoryCount<=10||optionalSize<200||!get(nt+24+112+80,&configRva,4)||
     !get(nt+24+116+80,&configSize,4)||configSize<0xd0||
     !get(size_t(configRva)+0xc8,&metadata,8)||metadata<base||metadata-base>=imageSize||
     !get(size_t(metadata-base)+4,&mapRva,4)||!get(size_t(metadata-base)+8,&mapCount,4)||
     !mapCount||mapCount>65536)return fail;
  auto kind=[&](uint32_t rva) {
    int answer=-1;
    for(uint32_t i=0;i<mapCount;i++) {
      uint32_t start=0,length=0;
      if(!get(size_t(mapRva)+size_t(i)*8,&start,4)||!get(size_t(mapRva)+size_t(i)*8+4,&length,4))return -1;
      const uint32_t from=start&~3u;
      if(rva>=from&&rva-from<length) {if(answer!=-1)return -1;answer=int(start&3u);}
    }
    return answer;
  };
  if(kind(entry)!=2||kind(uint32_t(target))!=1)return fail;
  return {base,base+entry,base+uintptr_t(target)};
}
}

#ifdef _WIN32
namespace queen_self_export {
inline bool ReadMapped(uintptr_t address,void* out,size_t size) {
  if(address+size<address)return false;
  uintptr_t cursor=address;
  while(cursor<address+size) {
    MEMORY_BASIC_INFORMATION region{};
    if(!VirtualQuery(reinterpret_cast<void*>(cursor),&region,sizeof(region))||region.State!=MEM_COMMIT||
       (region.Protect&(PAGE_NOACCESS|PAGE_GUARD)))return false;
    const DWORD protection=region.Protect&0xff;
    if(protection!=PAGE_READONLY&&protection!=PAGE_READWRITE&&protection!=PAGE_WRITECOPY&&
       protection!=PAGE_EXECUTE_READ&&protection!=PAGE_EXECUTE_READWRITE&&protection!=PAGE_EXECUTE_WRITECOPY)return false;
    const uintptr_t end=reinterpret_cast<uintptr_t>(region.BaseAddress)+region.RegionSize;
    if(end<=cursor)return false;
    cursor=end<address+size?end:address+size;
  }
  std::memcpy(out,reinterpret_cast<void*>(address),size);return true;
}
inline Result Resolve(uintptr_t selfImageAddress,uintptr_t compilerFunctionAddress,const char* name) {
  // virtual_ios.c copies and registers the ENTIRE image, including headers.
  // Canonicalize the self-image address before reading EAT or querying a loader.
  const uintptr_t base=IosJitReverseTranslate(selfImageAddress);
  const uintptr_t peFunction=IosJitReverseTranslate(compilerFunctionAddress);
  uint16_t mz=0;uint32_t nt=0,signature=0,size=0;
  if(!ReadMapped(base,&mz,2)||mz!=0x5a4d||!ReadMapped(base+0x3c,&nt,4)||nt<0x40||nt>0x100000||
     !ReadMapped(base+nt,&signature,4)||signature!=0x4550||!ReadMapped(base+nt+24+56,&size,4)||
     size<0x1000||size>0x20000000||peFunction<base||peFunction-base>=size)return {};
  return Find(base,size,name,ReadMapped);
}
}
#endif
