from pathlib import Path
import hashlib,random,subprocess,tempfile
root=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as d:
 exe=Path(d)/'hash'
 subprocess.run(['c++','-std=c++17','-O2','-Wall','-Wextra','-Werror','-fsanitize=undefined',str(root/'fingerprint-hash.cpp'),'-o',str(exe)],check=True)
 rng=random.Random(667)
 cases=[b'',b'abc',b'a'*1000000]+[rng.randbytes(n) for n in list(range(130))+[255,256,511,512,1000,4096,65537]]
 for b in cases:
  result=subprocess.check_output([str(exe)],input=b).decode().strip()
  assert result==hashlib.sha256(b).hexdigest(),len(b)
 print('PASS',len(cases),'SHA256 vectors, boundaries, randomized inputs; all fingerprint headers compiled')
