"""Copy small, non-secret receipts only. Never include worker pairing tokens or Codex transcripts."""
from pathlib import Path
import json
import hashlib
from datetime import datetime, timezone
import subprocess
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'receipts/touch';out.mkdir(parents=True,exist_ok=True)
sources={'generation-controller':'.touch-worker-demo/documented-defaults-final/roundtrip-receipt.json','generation-observed-bindings':'.touch-worker-demo/observed-bindings-final/roundtrip-receipt.json','rejected-generation':'.touch-worker-demo/roundtrip/server/b2c8962db5b66d02870857cbc88678f5bc0f7e2357445534b137f349aeada2c8.receipt.json'}
for name,path in sources.items():
    p=ROOT/path
    if p.exists():
        data=json.loads(p.read_text(encoding='utf-8'));(out/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
key='b2c8962db5b66d02870857cbc88678f5bc0f7e2357445534b137f349aeada2c8'
state=ROOT/'.touch-worker-demo/documented-defaults-final/server'
if state.exists():
    data=json.loads((state/(key+'.receipt.json')).read_text(encoding='utf-8'))
    data['searches']=json.loads((state/(key+'.research.json')).read_text(encoding='utf-8'))
    data['generatedPackSHA256']=hashlib.sha256((state/(key+'.pack.json')).read_bytes()).hexdigest()
    data['deliveredPackSHA256']=hashlib.sha256((ROOT/'packs/pilots/dread-delusion.json').read_bytes()).hexdigest()
    data['review']='Removed an incorrect model caveat about renderer styling; production renderer already supplies thin translucent outlines. No binding changes.'
    (out/'generation-research.json').write_text(json.dumps(data,indent=2)+'\n')
for run,name in [('41325781149','host-checks'),('41312177828','guest-diagnostic-build'),('41325781697','archive-attempt'),('41332474319','sideload-packages'),('41322897101','archive-actor-hooks'),('41319510340','archive-missing-optins'),('41322894288','base-runtime-preflight'),('41313095321','archive-missing-converter'),('41316978984','archive-release-pin'),('41318954382','production-publisher'),('41324076244','simulator-previews')]:
    r=subprocess.run(['gh','run','view',run,'--repo','arjunkl/bcd-touch','--json','headSha,url,status,conclusion,jobs'],capture_output=True,text=True,check=True)
    data=json.loads(r.stdout)
    data['capturedAt']=datetime.now(timezone.utc).isoformat()
    # Compact steps retain failures and the currently active step; avoid multi-thousand-line routine logs.
    data['jobs']=[dict(name=j['name'],status=j['status'],conclusion=j['conclusion'],steps=[s for s in j['steps'] if s['conclusion']=='failure' or s['status']=='in_progress']) for j in data['jobs']]
    (out/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
print(out)
