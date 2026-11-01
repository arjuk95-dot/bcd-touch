from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'.github/workflows/touch-ipa.yml';d=yaml.safe_load(p.read_text());d.pop(True,None);d['on']={'workflow_dispatch':None}
for step in d['jobs']['build']['steps']:
    if step.get('name','').startswith('Build native wine'):
        step['run']=step['run'].replace('__tools__','__tooldeps__').replace('"$N" include ', '"$N" include/all ')
p.write_text(yaml.safe_dump(d,sort_keys=False,width=160))
