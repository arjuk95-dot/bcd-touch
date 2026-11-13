#!/usr/bin/env python3
import pathlib,subprocess,tempfile,os
root=pathlib.Path(__file__).resolve().parents[2]
h=(root/'app/Madeira/BCDSulfurSprintPolicy.h').read_text()
mutants=[('forward>1.15','forward>1.0'),('forward*0.45','forward*0.8'),('>=0.120','>=0.010'),('if(s->emitted) return 0;','if(0) return 0;'),('now<s->lastTime','0'),('if(!allowed || !isfinite(x)','if((!allowed && 0) || !isfinite(x)'),('s->dwelling=0; return 0;','return 0;')]
with tempfile.TemporaryDirectory() as d:
 p=pathlib.Path(d)
 def run(src):
  (p/'BCDSulfurSprintPolicy.h').write_text(src)
  subprocess.run([os.environ.get('CC','cc'),'-std=c11','-Wall','-Wextra','-Werror','-I',d,str(root/'tests/host/sulfur_sprint_policy_test.c'),'-lm','-o',str(p/'test')],check=True)
  return subprocess.run([str(p/'test')],capture_output=True,text=True)
 r=run(h);assert r.returncode==0,r.stderr;print(r.stdout,end='')
 for a,b in mutants:
  assert a in h
  assert run(h.replace(a,b)).returncode!=0,a
 print('PASS: seven compiled controller sprint mutants rejected')
