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
    stabilized=stabilize(regenerated,p);w.validate(stabilized)
    assert [a['id'] for a in stabilized['actions']]==[a['id'] for a in p['actions']]
    for mutate in [lambda v:v.update(version=2),lambda v:(v.update(inputMode='controller'),v['actions'][0].update(output='mouse:left')),lambda v:v['phone']['controls'][0].update(hitRadius=.9),lambda v:v['identity'].update(build='wrong')]:
        bad=copy.deepcopy(p);mutate(bad)
        try:w.validate(bad,p['identity'])
        except Exception:pass
        else:raise AssertionError('Invalid pack accepted')
    with tempfile.TemporaryDirectory() as tmp:
        worker=w.Worker(tmp)
        request=dict(version=1,identity=p['identity'],title=p['title'],bindings={},requirements={})
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
