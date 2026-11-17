#!/usr/bin/env python3
"""Reproduce retained native source overlays, apply only GS compiler half."""
import hashlib,json,pathlib,re,shutil,subprocess,sys
r=pathlib.Path.cwd();cfg=pathlib.Path(sys.argv[1]).resolve();o=r/'build-out/queen-gs-native-source';o.mkdir(exist_ok=False)
shutil.copytree(r/'dxmt',o/'dxmt',ignore=shutil.ignore_patterns('.git'))
(o/'build').mkdir();shutil.copyfile(r/'build/madeira_cfg.h',o/'build/madeira_cfg.h')
(o/'research').mkdir();shutil.copytree(r/'research/remote-metal',o/'research/remote-metal')
(o/'toolchains').symlink_to(r/'toolchains',target_is_directory=True)
(o/'build/dxmt-ios').mkdir(); (o/'build/dxmt-ios/shader-headers').symlink_to(r/'build/dxmt-ios/shader-headers',target_is_directory=True)
retained='2833ed85d945bb6623611200b558057f36f60f20'
# App-only source intentionally omits the full native workflow; recover its
# exact overlay ordering from the retained donor commit, not the current tree.
wf=subprocess.check_output(['git','show',retained+':.github/workflows/build-ipa.yml'],cwd=r).decode('utf-8')
chain=re.findall(r'python3 (tools/patch-(?:dxmt|airconv|winemetal)-[\w.-]+\.py)',wf)
assert chain
for path in chain:
 original=subprocess.check_output(['git','show',retained+':'+path],cwd=r)
 assert (r/path).read_bytes()==original, ('Retained native overlay drift',path)
for script in chain:subprocess.run([sys.executable,str(r/script)],cwd=o,check=True)
subprocess.run(['git','init','-q'],cwd=o/'dxmt',check=True)
manifest={str(p.relative_to(o/'dxmt')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (o/'dxmt/src/airconv').rglob('*') if p.is_file()}
subprocess.run(['git','apply','--check','--include=src/airconv/*',str(cfg/'queen-gs-tight-payload.patch')],cwd=o/'dxmt',check=True)
subprocess.run(['git','apply','--include=src/airconv/*',str(cfg/'queen-gs-tight-payload.patch')],cwd=o/'dxmt',check=True)
(o/'source-receipt.json').write_text(json.dumps({'workflow_patch_chain':chain,'before_airconv_files':manifest,'retained_source_head':'2833ed85d945bb6623611200b558057f36f60f20','candidate_patch_sha256':hashlib.sha256((cfg/'queen-gs-tight-payload.patch').read_bytes()).hexdigest()},indent=2))
print(o)
