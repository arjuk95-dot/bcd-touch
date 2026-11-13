#!/usr/bin/env python3
"""Data contracts for reconstructed native controller profile, not UIKit/game validation."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[2]
p=json.loads((root/'packs/pilots/sulfur-reviewed-controller.json').read_text())
s=(root/'app/Madeira/BCDSulfurPack.swift').read_text()
embedded=s.split('private static let template = #"""\n',1)[1].split('\n"""#',1)[0]
assert json.loads(embedded)==p
assert hashlib.sha256(embedded.encode()).hexdigest()==re.search(r'Canonical reviewed data SHA256: ([0-9a-f]{64})',s)[1]
assert p['version']==6 and p['inputMode']=='controller' and p['lookMode']=='relativeMouse'
assert 'firstPersonMovement' not in p and 'digitalMovement' not in p and 'cursorControls' not in p
expected=dict(move='LS',attack='RT',melee='X',interact='A',inventory='Menu',pause='View',swap='Y',aim='LT',jump='B',crouch='R3',amulet='D↑',**{'inspect-weapon':'D↓','alternate-melee':'LB','sprint':'L3'})
inventory={'inventory-move':'X','inventory-use':'A','inventory-close':'B','inventory-rotate-left':'LB','inventory-rotate-right':'RB'}
expected.update(inventory)
a={x['id']:x for x in p['actions']};assert {k:v['output'] for k,v in a.items()}==expected
assert p['contexts']==['onFoot','inventory'] and a['move']['contexts']==['onFoot','inventory']
assert all(a[k]['contexts']==['inventory'] and a[k]['behavior']=='tap' for k in inventory)
assert all(a[k]['contexts']==['onFoot'] for k in a if k not in inventory and k!='move')
assert not any(v['output']=='Y' for k,v in a.items() if 'inventory' in v['contexts'])
assert all(not x['output'].startswith(('key:','mouse:')) for x in a.values())
assert a['sprint']['behavior']=='tap' and a['alternate-melee']['behavior']=='hold'
assert len(p['radial'])==8 and len(set(p['radial']))==8
for device in ['phone','pad']:
 l=p[device];controls={c['action']:c for c in l['controls'] if c['role']!='radial'}
 assert controls['move']['role']=='move'
 assert controls['attack']['x']<controls['melee']['x'] and controls['attack']['radius']>controls['melee']['radius']
 assert controls['attack']['role']=='fireAim'
 reachable=set(controls)|set(p['radial']);assert set(a)<=reachable
 r=l['aimRect']
 for c in l['controls']:
  h=c['hitRadius'];assert c['radius']==h
  assert c['x']+h<=r['x'] or c['x']-h>=r['x']+r['width'] or c['y']+h<=r['y'] or c['y']-h>=r['y']+r['height']
assert '390aa3800421d3076344c2ea4954ea371edd1423e34b3db98d49cd033d3c6c5e' in s
assert 'hold-left-shift-v1' not in s and 'native-l3-entry-v1' in s
print('PASS: controller-only action map, alias provenance, canonical template, Attack/Melee layout, clear swipe region and reachability')
print('SCOPE: this data-contract check does not execute Swift, UIKit or guest input; consult separate portable/native test receipts.')

print("PASS: same-pack native inventory visibility/actions, no destructive drop or mouse drag; runtime camera/sprint suppression remains integration responsibility")
