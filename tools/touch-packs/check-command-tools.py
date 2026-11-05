"""Verify the actual x86 tools a session links from the built i386 farm."""
import hashlib,json,re,struct
from pathlib import Path
root=Path(__file__).resolve().parents[2]
bridge=(root/'app/Madeira/WineProcessBridge.m').read_text(encoding='utf-8')
start=bridge.index('/* madeira-bcd (2026-11-01): MADEIRA_SYSTEM32_X86_TOOLS')
tools=re.findall(r'"([a-z0-9]+\.exe)"',bridge[start:].split('};',1)[0])
assert len(tools)==26 and len(set(tools))==26
checked=[]
for name in tools:
    path=root/'app/Madeira/i386-windows'/name
    data=path.read_bytes()
    assert data[:2]==b'MZ','Missing or invalid built tool: '+name
    offset=struct.unpack_from('<I',data,0x3c)[0]
    assert data[offset:offset+4]==b'PE\0\0' and struct.unpack_from('<H',data,offset+4)[0]==0x14c,'Not an x86 PE tool: '+name
    checked.append(dict(name=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
out=root/'build-out';out.mkdir(exist_ok=True)
(out/'x86-command-tools.json').write_text(json.dumps(dict(kind='Built i386 farm command-tool inspection',tools=checked),indent=2)+'\n',encoding='utf-8')
print('PASS: all 26 linked command-line tools exist as actual x86 PE files in the built farm')
