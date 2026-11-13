#!/usr/bin/env python3
"""Exact-default model contract, not guest runtime validation."""
import json,pathlib
r=pathlib.Path(__file__).resolve().parents[2]
p=json.loads((r/'packs/pilots/dread-delusion.json').read_text())
a={x['id']:x for x in p['actions']}
assert {k:v['output'] for k,v in a.items()}==dict(move='LS',attack='RT',interact='A',block='RB',inventory='X',jump='Y',menu='Menu',map='View',**{'next-weapon':'D↓','next-item':'D→','next-spell':'D←','spell':'LT','sprint':'LB','crouch':'R3','item':'D↑'})
assert all(a[x]['behavior']=='hold' for x in ['attack','next-weapon','spell','block','sprint'])
assert p['lookMode']=='relativeMouse' and p['version']==6
assert len(p['radial'])<=8
for device in ['phone','pad']:
 controls=p[device]['controls'];assert set(a)<=set(p['radial'])|{c['action'] for c in controls}
 for c in controls:
  assert c['action'] in a
  assert c['radius']==c['hitRadius']
  assert 0<=c['x']-c['radius'] and c['x']+c['radius']<=1
assert all(x['contexts']==['onFoot'] for x in a.values())
assert all(x['evidence']=='installed-native-json' for x in a.values())
print('PASS Dread native defaults, duration preservation, reachability; runtime unverified')
