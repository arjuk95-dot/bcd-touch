"""Wine ARM64EC images use AMD64 PE headers plus CHPE native code maps."""
import struct
def inspect_image(b):
 assert b[:2]==b'MZ'
 off=struct.unpack_from('<I',b,60)[0];assert b[off:off+4]==b'PE\0\0'
 machine,count=struct.unpack_from('<HH',b,off+4);opt=off+24
 optional_size=struct.unpack_from('<H',b,off+20)[0];sections=opt+optional_size
 def rva(value):
  for i in range(count):
   size,base,raw_size,raw=struct.unpack_from('<IIII',b,sections+40*i+8)
   if base<=value<base+max(size,raw_size):
    mapped=raw+value-base;assert 0<=mapped<len(b);return mapped
  raise ValueError('RVA outside PE sections: '+hex(value))
 result={'machine':hex(machine),'architecture':{0x14c:'i386',0xaa64:'arm64',0x8664:'x86_64',0xa641:'arm64ec',0xa64e:'arm64x'}.get(machine,'unknown')}
 if machine in [0x8664,0xa641,0xa64e] and struct.unpack_from('<H',b,opt)[0]==0x20b:
  base=struct.unpack_from('<Q',b,opt+24)[0]
  lc,size=struct.unpack_from('<II',b,opt+112+10*8)
  if lc and size>=208:
   metadata=struct.unpack_from('<Q',b,rva(lc)+200)[0]
   if metadata:
    version,map_rva,n=struct.unpack_from('<III',b,rva(metadata-base));assert 1<=n<=4096
    ranges=[];moves=stores=0
    for i in range(n):
     start,length=struct.unpack_from('<II',b,rva(map_rva)+i*8);kind=start&3;start&=~3
     ranges.append({'rva':hex(start),'bytes':length,'type':kind})
     if kind not in [0,1]:continue # Never decode the AMD64 thunks as ARM64.
     data=b[rva(start):rva(start)+length]
     for (word,) in struct.iter_unpack('<I',data[:len(data)//4*4]):
      if word&0xffe0ffe0==0xaa0003e0 and (word>>16)&31==18:moves+=1
      if word&31==18 and ((word&0xffc00000==0xf9000000) or (word&0xffe00c00==0xf8000000) or (word&0xffc00000==0xa9000000)):stores+=1
      if word&0xffc00000==0xa9000000 and (word>>10)&31==18:stores+=1
    assert any(x['type']==1 for x in ranges),'Missing ARM64EC native code range'
    result.update(architecture='arm64ec-hybrid',chpeVersion=version,codeRanges=ranges,explicitTEBMoves=moves,directTEBStores=stores)
 return result
