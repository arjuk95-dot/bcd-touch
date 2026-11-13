#!/usr/bin/env python3
"""Data/source consistency only; Swift fixtures require integration compiler run."""
import pathlib,json,hashlib,re
r=pathlib.Path(__file__).resolve().parents[2]
s=(r/'app/Madeira/BCDDreadPack.swift').read_text()
a=re.search(r'template = #"""\n(.*?)\n"""#',s,re.S).group(1)
b=(r/'packs/pilots/dread-delusion.json').read_text().strip()
assert a==b and hashlib.sha256(a.encode()).hexdigest() in s
p=json.loads((r/'packs/personal/tenebris-somnia-owner-iphone.json').read_text())
assert p['version']==3 and p['id']=='tenebris-owner-mockup-v3' and p['lookMode']=='none'
for name,output,behavior in [('raw-lt','LT','toggle'),('raw-rt','RT','tap'),('raw-ls','LS','hold')]:
 actions=[a for a in p['actions'] if a['id']==name];assert len(actions)==1
 assert actions[0]['output']==output and actions[0]['behavior']==behavior
print('PASS: unchanged Dread embedded template/hash and exact Tenebris fixture prerequisites')
print('SCOPE: this structural check does not execute Swift; consult separate portable/native test receipts.')
