"""Host/transport fixtures, explicitly not device gameplay or genuine Codex generation."""
from pathlib import Path
import copy
import importlib.util
import json
import tempfile
import sys
import socket
import subprocess
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/touch-packs'))
spec=importlib.util.spec_from_file_location('worker',ROOT/'tools/touch-packs/worker.py');w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
packs=list((ROOT/'packs/pilots').glob('*.json'))
assert packs, 'Pilot packs missing'
icon_catalog=json.loads((ROOT/'tools/touch-packs/icon-catalog.json').read_text(encoding='utf-8'))
assert len(icon_catalog)>40 and len({entry['id'] for entry in icon_catalog})==len(icon_catalog)
# New output vocabulary is versioned, mode-checked and never permits arbitrary key codes.
v2=copy.deepcopy(json.loads((ROOT/'packs/pilots/dread-delusion.json').read_text(encoding='utf-8')))
v2['version']=2;v2['inputMode']='keyboardMouse'
reachable=set(v2['radial']) | {g['action'] for g in v2['gestures']}
for device in ['phone','pad']:reachable.update(c['action'] for c in v2[device]['controls'])
v2['actions']=[a for a in v2['actions'] if a['id'] in reachable]
for a in v2['actions']:a['output']='key:65'
for device in ['phone','pad']:
    for c in v2[device]['controls']:c['role']='button'
for output in ['keys:17+67','keys:17+16+65','mouse:middle','mouse:wheelUp','mouse:wheelDown']:
    v2['actions'][0].update(output=output,behavior='tap');w.validate(v2)
for output in ['key:0','key:256','key:+65','keys:17','keys:17+17','keys:17+65+66+67+68']:
    v2['actions'][0]['output']=output
    try:w.validate(v2)
    except Exception:pass
    else:raise AssertionError('Invalid extended binding accepted '+output)
v2['actions'][0].update(output='mouse:wheelUp',behavior='hold')
try:w.validate(v2)
except Exception:pass
else:raise AssertionError('Holding a wheel action must be rejected')
# V3 interactions are explicit and must not be reinterpreted by older clients.
owner=json.loads((ROOT/'packs/personal/tenebris-somnia-owner-iphone.json').read_text(encoding='utf-8'))
w.validate(owner,personal=True)
assert owner['lookMode']=='none' and next(a for a in owner['actions'] if a['output']=='LT')['behavior']=='toggle'
for mutate in [lambda p:p.update(version=2),lambda p:p['phone']['controls'][5].update(slideToAction='missing'),lambda p:p['actions'][1].update(output='RS'),lambda p:p['actions'][2].update(behavior='hold'),lambda p:p['actions'][2].update(icon='bcd.unknown')]:
    bad=copy.deepcopy(owner);mutate(bad)
    try:w.validate(bad,personal=True)
    except Exception:pass
    else:raise AssertionError('Malformed V3 interaction accepted')
v3=copy.deepcopy(json.loads((ROOT/'packs/pilots/dread-delusion.json').read_text(encoding='utf-8')));v3['version']=3
with tempfile.TemporaryDirectory() as temporary:
    folder=Path(temporary);service=w.Worker(folder);key=w.key_for(v3['identity'])
    w.atomic(folder/(key+'.pack.json'),v3)
    req=dict(version=1,identity=v3['identity'],title=v3['title'],bindings={},requirements={'packVersion':'2'})
    assert service.submit(key,req)[0]==409 and not list(folder.glob('*.request.json')), 'Old client must not regenerate or overwrite a newer cached pack'
    req['requirements']['packVersion']='3';assert service.submit(key,req)[0]==200
    service.pool.shutdown()
# Personal exports can occupy the swipe rectangle, overlap and reach the display edge.
free=copy.deepcopy(json.loads((ROOT/'packs/pilots/dread-delusion.json').read_text(encoding='utf-8')))
free['version']=2
for device in ['phone','pad']:
    for c in free[device]['controls'][:2]:c.update(x=.5,y=.5,coordinateSpace='screen')
    free[device]['controls'][-1].update(x=0,y=1,coordinateSpace='screen')
w.validate(free,personal=True)
try:w.validate(free)
except Exception:pass
else:raise AssertionError('Generated validation accepted personal display placement')
for mutation in [lambda p:p['phone']['controls'][0].update(coordinateSpace='script'),lambda p:p['phone']['controls'][0].update(x=1.01),lambda p:p.update(version=1),lambda p:p['phone']['controls'][0].update(hitRadius=.9)]:
    broken=copy.deepcopy(free);mutation(broken)
    try:w.validate(broken,personal=True)
    except Exception:pass
    else:raise AssertionError('Personal layout bypassed structural validation')
# Store-neutral request construction reads only explicitly selected bounded binding files.
request_spec=importlib.util.spec_from_file_location('request_game',ROOT/'tools/touch-packs/request-game.py')
request_module=importlib.util.module_from_spec(request_spec);request_spec.loader.exec_module(request_module)
with tempfile.TemporaryDirectory() as temporary:
    binding=Path(temporary)/'controls.ini';binding.write_text('jump=Space',encoding='utf-8')
    generic=request_module.make_request('Unidentified fixture','Games/Unknown.exe',bindings=[binding],mode='keyboardMouse')
    assert generic['identity']['executable']=='games/unknown.exe' and list(generic['bindings'])==['player/controls.ini']
    assert generic['identity']['bindingDigest']==w.hashlib.sha256(w.canonical(generic['bindings'])).hexdigest()
    binding.write_bytes(b'x'*32769)
    try:request_module.make_request('Fixture','fixture.exe',bindings=[binding])
    except ValueError:pass
    else:raise AssertionError('Oversized binding file accepted')

from dread_bindings import apply_dread_bindings
from inspect_unity_bindings import extract
import struct
def unityString(value):
    encoded=value.encode('utf-8');raw=struct.pack('<I',len(encoded))+encoded
    return raw+b'\0'*((-len(raw))%4)
record=b''.join(unityString(s) for s in ['8ad5bc9a-0620-48e4-8a31-64d1246589cc','<Gamepad>/rightShoulder','','','Controller','Block'])+struct.pack('<I',0)
parsed=extract(record)
assert len(parsed)==1 and parsed[0]['action']=='Block' and parsed[0]['path']=='<Gamepad>/rightShoulder'
assert not extract(b'<Gamepad>/rightShoulder') and not extract(record[:-5]), 'Truncated or incidental strings are not binding evidence'
dreadRequest=json.loads((ROOT/'packs/requests/dread-delusion-installed-iphone.json').read_text(encoding='utf-8'))
dreadPilot=json.loads((ROOT/'packs/pilots/dread-delusion-installed-iphone.json').read_text(encoding='utf-8'))
dread=apply_dread_bindings(dreadPilot,dreadRequest);w.validate(dread,dreadRequest['identity'])
byID={a['id']:a for a in dread['actions']}
from layout_policy import apply_layout_policy,check_generated_geometry
layout_request=dict(requirements=dict(genre='first-person'))
policy=apply_layout_policy(copy.deepcopy(dread),layout_request)
assert policy['phone']['controls']==dread['phone']['controls'] and policy['pad']['controls']==dread['pad']['controls'], 'Valid per-game layout was flattened into generic slots'
check_generated_geometry(policy)
left=copy.deepcopy(dread)
for device in ['phone','pad']:
    primary=next(c for c in left[device]['controls'] if c['role']=='fireAim')
    duplicate=dict(primary,id='left-fire-fixture',x=.10,y=.30,radius=.04,hitRadius=.04)
    left[device]['controls'].append(duplicate)
left=apply_layout_policy(left,layout_request)
assert all(next(c for c in left[device]['controls'] if c['id']=='left-fire-fixture')['role']=='button' for device in ['phone','pad'])
collision=copy.deepcopy(dread)
control=next(c for c in collision['phone']['controls'] if c['role']=='fireAim')
collision['phone']['controls'].append(dict(control,id='colliding-fixture'))
try:check_generated_geometry(collision)
except ValueError:pass
else:raise AssertionError('Overlapping generated buttons accepted')
keyboard_policy=copy.deepcopy(json.loads((ROOT/'packs/pilots/chronicles-of-the-wolf.json').read_text(encoding='utf-8')))
assert apply_layout_policy(copy.deepcopy(keyboard_policy),layout_request)==keyboard_policy,'Keyboard layout was overwritten by controller hierarchy'
check_generated_geometry(json.loads((ROOT/'receipts/touch/authoring-20261103/chronicles-generated-v2.json').read_text(encoding='utf-8')))


for altered,requirements in [(dread,dict(packVersion='2',inputMode='keyboardMouse')),(dict(dread,version=2),dict(packVersion='1',inputMode='controller'))]:
    try:w.validate_result(altered,dict(identity=dread['identity'],requirements=requirements))
    except Exception:pass
    else:raise AssertionError('Ignored requested input mode or client version')

assert {id:byID[id]['output'] for id in ['block','spell','sprint','crouch','use-item','raw-y','raw-a']}==dict(block='RB',spell='LT',sprint='LB',crouch='R3',**{'use-item':'D↑','raw-y':'Y','raw-a':'A'})
assert byID['block']['behavior']=='hold' and byID['block']['contexts']==['onFoot']
assert byID['panel-right']['contexts']==['menu'] and byID['ascend']['contexts']==['airship']
assert all(a['output'] in w.OUTPUTS for a in dread['actions'])
actualRemaps=copy.deepcopy(dreadRequest);actualRemaps['bindings']={'actual-input-file':'player overrides'}
assert apply_dread_bindings(dreadPilot,actualRemaps)==dreadPilot, 'Defaults must never replace unparsed actual remaps'
import math
for device,aspect in [('phone',2.0),('pad',1.33)]:
    for context in dread['contexts']:
        visible=[c for c in dread[device]['controls'] if c['role'] not in ['move','radial'] and context in byID[c['action']]['contexts']]
        for i,c in enumerate(visible):
            for other in visible[i+1:]:
                assert math.hypot((c['x']-other['x'])*aspect,c['y']-other['y'])>=c['hitRadius']+other['hitRadius'], 'Same-context buttons overlap'
def gameDeadzone(value,minimum,maximum=.925): return max(0,min(1,(value-minimum)/(maximum-minimum)))
oldFine=.18+.82*(.2*60/900)
newFine=dread['aim']['deadZone']+(1-dread['aim']['deadZone'])*(.2*60/dread['aim']['fullSpeed'])
assert gameDeadzone(gameDeadzone(oldFine,.125),.2)==0
assert gameDeadzone(gameDeadzone(newFine,.125),.2)>0, 'Fine aim must survive the installed binding and assumed standard control dead zones'
assert w.reference_for(dict(storeID='local',executable='Games/Dread Delusion.exe'))['identifiedBy'].startswith('unique executable')
assert w.reference_for(dict(storeID='local',executable='unknown.exe')) is None
local_request=json.loads((ROOT/'packs/requests/chronicles-of-the-wolf.json').read_text(encoding='utf-8'));local_request['identity']['storeID']='local'
local_pack=json.loads((ROOT/'packs/pilots/chronicles-of-the-wolf.json').read_text(encoding='utf-8'));local_pack['identity']=local_request['identity']
local_pack=w.apply_installed_bindings(local_pack,local_request);w.validate(local_pack,local_request['identity'])
assert next(a for a in local_pack['actions'] if a['id']=='attack')['output']=='key:90'
for path in packs:
    p=json.loads(path.read_text(encoding='utf-8'));w.validate(p)
    from stable_ids import stabilize
    regenerated=copy.deepcopy(p);remap={a['id']:'new-'+a['id'] for a in regenerated['actions']}
    for a in regenerated['actions']:a['id']=remap[a['id']]
    for device in ['phone','pad']:
        for c in regenerated[device]['controls']:c['action']=remap.get(c['action'],c['action']);c['id']='new-'+c['id']
    regenerated['radial']=[remap[x] for x in regenerated['radial']]
    for g in regenerated['gestures']:g['action']=remap[g['action']]
    for name,keys in [('digitalMovement',['left','right','up','down']),('cursorControls',['fire','inventory','pause','throwAction','primaryClick','secondaryClick'])]:
        if name in regenerated:
            for key in keys:regenerated[name][key]=remap[regenerated[name][key]]
    stabilized=stabilize(regenerated,p);w.validate(stabilized)
    assert [a['id'] for a in stabilized['actions']]==[a['id'] for a in p['actions']]
    for mutate in [lambda v:v.update(version=999),lambda v:(v.update(inputMode='controller'),v['actions'][0].update(output='mouse:left')),lambda v:v['phone']['controls'][0].update(hitRadius=.9),lambda v:v['identity'].update(build='wrong')]:
        bad=copy.deepcopy(p);mutate(bad)
        try:w.validate(bad,p['identity'])
        except Exception:pass
        else:raise AssertionError('Invalid pack accepted')
    with tempfile.TemporaryDirectory() as tmp:
        worker=w.Worker(tmp)
        request=dict(version=1,identity=p['identity'],title=p['title'],bindings={},requirements={'packVersion':str(p['version'])})
        key=w.key_for(p['identity']);w.atomic(Path(tmp)/(key+'.pack.json'),p)
        assert worker.submit(key,request)[0]==200 # cached install, duplicate event, next process
        assert worker.submit(key,request)[0]==200
        restarted=w.Worker(tmp); assert restarted.submit(key,request)[0]==200
        # Personal controls remain a separate file when the worker replaces generated data.
        personal={'x':.12,'y':.88};w.atomic(Path(tmp)/'overrides.json',personal)
        w.atomic(Path(tmp)/(key+'.pack.json'),p)
        assert json.loads((Path(tmp)/'overrides.json').read_text(encoding='utf-8'))==personal
        # Fixture generator proves a corrupt worker cache is queued for repair, rather than served or stuck at 422.
        calls=[]
        worker.generate=lambda key,req:(calls.append(key),w.atomic(Path(tmp)/(key+'.pack.json'),p))
        broken=copy.deepcopy(p);broken['version']=999;w.atomic(Path(tmp)/(key+'.pack.json'),broken)
        assert worker.submit(key,request)[0]==202
        worker.pool.shutdown();restarted.pool.shutdown()
        assert calls==[key];w.validate(json.loads((Path(tmp)/(key+'.pack.json')).read_text(encoding='utf-8')),p['identity'])
    with tempfile.TemporaryDirectory() as tmp:
        worker=w.Worker(tmp);calls=[]
        worker.generate=lambda *args:calls.append(args)
        failed=dict(generation='initial',error='fixture rejection',failureKind='invalidPack',failureCount=1)
        w.atomic(Path(tmp)/(key+'.receipt.json'),failed)
        for _ in range(4):assert worker.submit(key,request)[0]==422
        assert not calls # Polling and duplicate notifications cannot create paid regeneration loops.
        failed.update(failureKind='generation',retryAfter=w.time.time()+60)
        w.atomic(Path(tmp)/(key+'.receipt.json'),failed)
        assert worker.submit(key,request)[0]==503
        failed.update(retryAfter=0,failureCount=3);w.atomic(Path(tmp)/(key+'.receipt.json'),failed)
        assert worker.submit(key,request)[0]==503
        retry=dict(request,generation='explicit-regeneration')
        assert worker.submit(key,retry)[0]==202
        worker.pool.shutdown();assert len(calls)==1
with tempfile.TemporaryDirectory() as tmp, socket.socket() as occupied:
    occupied.bind(('127.0.0.1',0));occupied.listen()
    folder=Path(tmp);token=folder/'token';token.write_text('fixture-token-with-at-least-24-characters')
    state=folder/'state';state.mkdir();w.atomic(state/(key+'.request.json'),request)
    result=subprocess.run([sys.executable,str(ROOT/'tools/touch-packs/worker.py'),'serve','--host','127.0.0.1','--port',str(occupied.getsockname()[1]),'--state',str(state),'--token-file',str(token),'--codex',str(folder/'must-not-be-executed')],capture_output=True,timeout=15)
    assert result.returncode!=0 and not list(state.glob('*.receipt.json')), 'An occupied worker port must fail before replaying generation jobs'
print('PASS: pilot validation, identity/mode/hit rejection, cache/restart/overrides, corrupt-cache recovery, bounded failed-generation retries and duplicate-server startup (host fixtures)')
