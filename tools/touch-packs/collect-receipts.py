"""Copy small, non-secret receipts only. Never include worker pairing tokens or Codex transcripts."""
from pathlib import Path
import json
import subprocess
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'receipts/touch';out.mkdir(parents=True,exist_ok=True)
sources={'generation-controller':'.touch-worker-demo/roundtrip-v4/roundtrip-receipt.json','generation-observed-bindings':'.touch-worker-demo/observed-bindings-final/roundtrip-receipt.json','rejected-generation':'.touch-worker-demo/roundtrip/server/b2c8962db5b66d02870857cbc88678f5bc0f7e2357445534b137f349aeada2c8.receipt.json'}
for name,path in sources.items():
    p=ROOT/path
    if p.exists():
        data=json.loads(p.read_text(encoding='utf-8'));(out/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
for run,name in [('41312251605','host-checks'),('41312177828','guest-diagnostic-build'),('41311552799','archive-attempt')]:
    r=subprocess.run(['gh','run','view',run,'--repo','arjunkl/bcd-touch','--json','headSha,url,status,conclusion,jobs'],capture_output=True,text=True,check=True)
    data=json.loads(r.stdout)
    # Compact steps retain failures and the currently active step; avoid multi-thousand-line routine logs.
    data['jobs']=[dict(name=j['name'],status=j['status'],conclusion=j['conclusion'],steps=[s for s in j['steps'] if s['conclusion']=='failure' or s['status']=='in_progress']) for j in data['jobs']]
    (out/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n')
print(out)
