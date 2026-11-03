"""Create a bounded, store-neutral generation request; never edits game configuration."""
import argparse
import hashlib
import json
from pathlib import Path

def make_request(title, executable, store_id='local', edition='installed', build='unreported', genre='auto', mode='auto', bindings=None):
    if not title.strip() or not executable.strip():
        raise ValueError('A game title and executable are required')
    if mode not in ['auto', 'controller', 'keyboardMouse']:
        raise ValueError('Unknown input mode')
    collected={};total=0
    for source in bindings or []:
        path=Path(source)
        with path.open('rb') as stream:data=stream.read(32769)
        if len(data)>32768 or total+len(data)>49152:
            raise ValueError('Each binding file is limited to 32 KiB; combined limit is 48 KiB')
        key='player/'+path.name
        if key in collected:raise ValueError('Binding file names must be distinct')
        collected[key]=data.decode('utf-8-sig');total+=len(data)
    canonical=json.dumps(collected,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()
    return dict(version=1,title=title,identity=dict(executable=executable.replace('\\','/').lower(),storeID=store_id,
        edition=edition,build=build,bindingDigest=hashlib.sha256(canonical).hexdigest()),bindings=collected,
        requirements=dict(packVersion='2',inputMode=mode,genre=genre,mode=mode,
            phone='iPhone landscape safe area; preserve continuous swipe space and thumb reach',
            pad='Independent iPad landscape reach layout',
            evidence='Prefer these actual player binding files; otherwise research primary game controls. Unknown bindings remain raw and unresolved.',
            status='Generated and validated do not mean physically tested.'))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--title',required=True);parser.add_argument('--executable',required=True)
    parser.add_argument('--store-id',default='local');parser.add_argument('--edition',default='installed');parser.add_argument('--build',default='unreported')
    parser.add_argument('--genre',choices=['auto','first-person','third-person','side-scroller','racing','strategy'],default='auto')
    parser.add_argument('--mode',choices=['auto','controller','keyboardMouse'],default='auto')
    parser.add_argument('--bindings',action='append',default=[]);parser.add_argument('--output',required=True)
    args=parser.parse_args()
    request=make_request(args.title,args.executable,args.store_id,args.edition,args.build,args.genre,args.mode,args.bindings)
    destination=Path(args.output);destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(request,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Request written; game files unchanged. Use worker.py generate REQUEST --state PRIVATE-DIRECTORY.')
