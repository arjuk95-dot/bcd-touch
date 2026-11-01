"""Host/transport fixtures, explicitly not device gameplay or genuine Codex generation."""
from pathlib import Path
import copy
import importlib.util
import json
import tempfile
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('worker',ROOT/'tools/touch-packs/worker.py');w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
packs=list((ROOT/'packs/pilots').glob('*.json'))
assert packs, 'Pilot packs missing'
for path in packs:
    p=json.loads(path.read_text(encoding='utf-8'));w.validate(p)
    for mutate in [lambda v:v.update(version=2),lambda v:v['actions'][0].update(output='mouse:left'),lambda v:v['phone']['controls'][0].update(hitRadius=.9),lambda v:v['identity'].update(build='wrong')]:
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
        worker.pool.shutdown();restarted.pool.shutdown()
print('PASS: pilot validation, wrong identity, mixed input rejection, hit-region limits, cached/duplicate/restart and separate override persistence (host fixtures)')
