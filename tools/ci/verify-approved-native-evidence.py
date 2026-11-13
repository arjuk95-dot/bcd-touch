#!/usr/bin/env python3
"""Reuse only artifact-backed native validation of byte-identical production and fixtures."""
import hashlib,json,os,pathlib,subprocess,urllib.request,zipfile,io
BASE='4aadd3ca1ec413bb27a7bfbeea9fc1b21a145d1c'
RUN=43402494507
ARTIFACT=14026124438
DIGEST='70c295a170c749e9b1eec20909dc324ba7535833b9074294357fcc7b2f10e6c3'
API='https://api.github.com/repos/arjuk95-dot/bcd-touch/'
headers={'Accept':'application/vnd.github+json','User-Agent':'BCD-native-provenance'}
if os.environ.get('GH_TOKEN'): headers['Authorization']='Bearer '+os.environ['GH_TOKEN']
def get(path):
    with urllib.request.urlopen(urllib.request.Request(API+path,headers=headers),timeout=45) as r:return json.load(r)
changed=subprocess.check_output(['git','diff','--name-only',BASE,'HEAD'],text=True).splitlines()
allowed={'.github/workflows/touch-profiles-ipa.yml','tests/host/check-bcd-touch.py','tools/ci/verify-approved-native-evidence.py'}
assert set(changed)<=allowed,('Production or native fixtures changed; fresh validation required',changed)
for path in ['app','packs','tools/touch-packs','tests/fixtures','tests/host/touch_pack_preview.swift','tests/host/touch_pack_ui_stubs.swift']:
    subprocess.run(['git','diff','--exit-code',BASE,'HEAD','--',path],check=True)
run=get(f'actions/runs/{RUN}');assert run['head_sha']==BASE and run['status']=='completed'
jobs=get(f'actions/runs/{RUN}/jobs')['jobs']
required={'Verify preserved touch controls and source integration','Validate production touch renderer and essential interaction ownership'}
passed={s['name'] for j in jobs for s in j['steps'] if s['conclusion']=='success'}
assert required<=passed,'Required native validation steps did not pass'
a=get(f'actions/artifacts/{ARTIFACT}')
assert a['workflow_run']['id']==RUN and a['workflow_run']['head_sha']==BASE
assert not a['expired'] and a['digest']=='sha256:'+DIGEST
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None
try:
    urllib.request.build_opener(NoRedirect).open(urllib.request.Request(API+f'actions/artifacts/{ARTIFACT}/zip',headers=headers),timeout=45)
    raise AssertionError('Expected signed artifact redirect')
except urllib.error.HTTPError as e:
    assert e.code in (301,302,303,307,308)
    location=e.headers['Location']
assert location.startswith('https://')
# Never forward the GitHub credential to the signed blob host.
with urllib.request.urlopen(location,timeout=90) as r:data=r.read()
assert hashlib.sha256(data).hexdigest()==DIGEST
out=pathlib.Path('touch-evidence');out.mkdir(exist_ok=True)
with zipfile.ZipFile(io.BytesIO(data)) as z:
    for info in z.infolist():
        p=pathlib.PurePosixPath(info.filename)
        assert not p.is_absolute() and '..' not in p.parts
    z.extractall(out)
for name in ['client-phase-1.txt','client-phase-2.txt','pack-interaction-regression.txt']:
    assert (out/name).read_text().startswith('PASS:'),name
assert len(list(out.glob('*.png')))==59
(out/'reused-native-provenance.json').write_text(json.dumps(dict(run=RUN,head=BASE,artifact=ARTIFACT,sha256=DIGEST,productionUnchanged=True,fullRunSucceeded=False,scope='Native Swift/UIKit and simulator fixture steps passed; remaining build checks still required'),indent=2))
print('Verified exact unchanged native production/fixture source and artifact SHA256; reusing successful native steps only. Full build and phone testing not claimed.')
