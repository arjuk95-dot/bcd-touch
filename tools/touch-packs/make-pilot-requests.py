"""Use local backup metadata only; copy binding evidence without saves/account data."""
from pathlib import Path
import hashlib
import json
import sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));from worker import canonical
backup=Path(sys.argv[1])
entries=json.loads((backup/'Documents/bcd-library.json').read_text(encoding='utf-8'))['entries']
out=HERE.parents[1]/'packs/requests';out.mkdir(parents=True,exist_ok=True)
for title,exe in [('Dread Delusion','windows_content/Dread Delusion.exe'),('Chronicles of the Wolf','Cotw.exe')]:
    e=next((e for e in entries if e['title']==title),None)
    bindings={}
    if title=='Chronicles of the Wolf':
        key='users/mobile/AppData/Roaming/Chronicles of the Wolf/config'
        bindings[key]=(backup/'Documents/wine/drive_c'/key).read_text(encoding='utf-8')
    identity=dict(executable=((e['relativePath']+'/'+exe) if e else exe).lower(),storeID='steam:'+str(e['steamAppID']) if e and e.get('steamAppID') else ('steam:1574240' if title=='Dread Delusion' else 'steam:2371890'),edition='installed',build=e.get('steamMetadataInstall') if e else 'unreported',bindingDigest=hashlib.sha256(canonical(bindings)).hexdigest())
    request=dict(version=1,identity=identity,title=title,bindings=bindings,requirements=dict(phone='iPhone 16 Pro Max; landscape safe area',pad='iPad landscape, distinct thumb reach',hud='BLACK shooter hierarchy for Dread; side-scroller for Chronicles. Reserve .4,.2,.3,.5 aim rectangle before controls.',mode='Controller-only. Bind unknown gameplay meanings to raw output labels; record all unresolved. Do not claim attack/fire semantics without evidence.',evidence='User confirms both titles run on iPhone. This does not verify their bindings. Chronicles numeric M..U controller codes are undocumented; keyboard named mappings alone are verified.',status='generated is not physically tested'))
    filename='dread-delusion' if title=='Dread Delusion' else 'chronicles-of-the-wolf'
    (out/(filename+'.json')).write_bytes(canonical(request))
    print(filename,identity)
