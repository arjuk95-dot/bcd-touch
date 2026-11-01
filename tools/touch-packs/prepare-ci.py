"""Derive an unsigned build from upstream's pinned macOS recipe, with no OTA/signing step."""
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[2]
src=yaml.safe_load((ROOT/'.github/workflows/build-ipa.yml').read_text())
src.pop(True,None); src['on']={'workflow_dispatch':None}
src['name']='BCD Touch Lab unsigned IPA'
src['concurrency']={'group':'bcd-touch-ipa','cancel-in-progress':False}
job=src['jobs']['build'];job.pop('if',None);job['permissions']={'contents':'read','actions':'read'}
steps=[]
for step in job['steps']:
    name=step.get('name','')
    if name=='Package Madeira and Madeira2 unsigned IPAs': break
    # Run the fork's targeted checks separately. Upstream's multi-hour recipe includes hundreds of unrelated checks.
    if name.startswith('Check ') or name.startswith('Dump first build errors'): continue
    steps.append(step)
steps += [
 {'name':'Package separate unsigned test IPA','run':'mkdir -p build-out/Payload\nditto build-out/Madeira.xcarchive/Products/Applications/Madeira.app build-out/Payload/Madeira.app\ncd build-out\nzip -qry BCD-Touch-Lab-unsigned.ipa Payload'},
 {'uses':'actions/upload-artifact@v4','if':'always()','with':{'name':'BCD-Touch-Lab-build','path':'build-out/BCD-Touch-Lab-unsigned.ipa\n*.log','if-no-files-found':'warn','retention-days':7}}
]
job['steps']=steps
(ROOT/'.github/workflows/touch-ipa.yml').write_text(yaml.safe_dump(src,sort_keys=False,width=160))
print(f'{len(steps)} build steps from the v0.1.626 recipe; signing and OTA excluded')
