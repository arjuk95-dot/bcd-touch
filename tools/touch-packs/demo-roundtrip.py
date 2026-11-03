"""Real HTTP miss -> desktop Codex -> validator -> returned pack, using recorded game metadata.
This client is a desktop fixture; it does not claim that an iPhone sent the request.
"""
from pathlib import Path
import argparse
import json
import secrets
import subprocess
import sys
import time
import urllib.request
import urllib.error
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE));from worker import canonical,key_for,validate
p=argparse.ArgumentParser();p.add_argument('--state',required=True);p.add_argument('--codex',default='codex');p.add_argument('--games',nargs='+');p.add_argument('--request-file',action='append',default=[]);p.add_argument('--output-dir');a=p.parse_args()
state=Path(a.state).resolve();state.mkdir(parents=True,exist_ok=True)
requests=[Path(file) for file in a.request_file]
requests.extend(HERE.parents[1]/'packs/requests'/(title+'.json') for title in (a.games or ([] if requests else ['dread-delusion','chronicles-of-the-wolf'])))
returned=Path(a.output_dir) if a.output_dir else state/'returned-packs'
returned.mkdir(parents=True,exist_ok=True)
token=secrets.token_urlsafe(32);tokenpath=state/'pairing-token.txt';tokenpath.write_text(token)
cmd=[sys.executable,str(HERE/'worker.py'),'serve','--state',str(state/'server'),'--token-file',str(tokenpath),'--port','18937','--codex',a.codex]
server=subprocess.Popen(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
receipt={'kind':'desktop HTTP client fixture using genuine Codex generation; no iOS install event/device gameplay','games':[]}
try:
    time.sleep(1)
    for request_path in requests:
        title=request_path.stem
        req=json.loads(request_path.read_text(encoding='utf-8'));key=key_for(req['identity'])
        url='http://127.0.0.1:18937/v1/packs/'+key
        def post():
            request=urllib.request.Request(url,data=canonical(req),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
            with urllib.request.urlopen(request,timeout=20) as response:return response.status,json.loads(response.read())
        status,_=post();row={'title':title,'initialHTTP':status};assert status==202,'Use a fresh demo state to demonstrate a miss'
        status,_=post();assert status==202;row['duplicateHTTP']=status
        started=time.time()
        while time.time()-started<730:
            time.sleep(3);status,body=post()
            if status==200:break
            failed=state/'server'/(key+'.receipt.json')
            if failed.exists() and not json.loads(failed.read_text()).get('validated'):raise RuntimeError(failed.read_text())
        assert status==200;validate(body,req['identity'])
        pilot=returned/(title+'.json');pilot.write_bytes(canonical(body))
        row.update(returnedHTTP=status,validated=True,physicallyTested=False,seconds=round(time.time()-started,2),cachedHTTP=post()[0],key=key)
        receipt['games'].append(row)
        print(json.dumps(row),flush=True)
finally:
    server.terminate();server.wait(timeout=10)
    (state/'roundtrip-receipt.json').write_bytes(canonical(receipt))
    print('Receipt:',state/'roundtrip-receipt.json',flush=True)
