"""Record actual CI inputs, patch hashes and MoltenVK's pinned dependency revisions."""
import hashlib,json,os,pathlib,shutil,subprocess
r=pathlib.Path(__file__).resolve().parents[2];g=r/'app/Madeira/gl'
revisions=r/'build/opengl-dependencies/MoltenVK/ExternalRevisions'
assert revisions.is_dir(),'MoltenVK revision directory missing'
files=sorted(p for p in revisions.rglob('*') if p.is_file())
assert files and sum(p.stat().st_size for p in files)<1024*1024
(g/'MoltenVK-ExternalRevisions.json').write_text(json.dumps({p.relative_to(revisions).as_posix():p.read_text() for p in files},indent=2)+'\n')
inputs=[r/'build/mesa-ios/build.sh',r/'build/mesa-ios/ios-arm64.cross',r/'build/moltenvk-ios/build.sh',r/'tools/opengl/build-dependencies.sh',*sorted((r/'build/mesa-ios/patches').glob('*.patch'))]
meta={'repository':os.environ.get('GITHUB_REPOSITORY'),'source':subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip(),'run':os.environ.get('GITHUB_RUN_ID'),'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),
      'inputs':{p.relative_to(r).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}}
(g/'source-build.json').write_text(json.dumps(meta,indent=2)+'\n')
shutil.copyfile(r/'tools/opengl/provenance.json',g/'provenance.json')
print(json.dumps(meta,indent=2))
