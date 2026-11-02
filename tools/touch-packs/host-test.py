"""Run upstream host checks with a working macOS 26 sanitizer runtime.

Apple's older ASan can deadlock before main on macOS 26:
https://github.com/llvm/llvm-project/issues/200447
Use the already installed Homebrew LLVM >=22 only for host test children.
The iOS app and runtime build retain their selected Xcode toolchain.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
script = (root / sys.argv[1]).resolve()
if not script.is_relative_to(root / 'tests/host'):
    raise ValueError('Expected a repository host test')
uses_asan = any('fsanitize=' in line and 'address' in line
                for line in script.read_text(encoding='utf-8').splitlines())
if not uses_asan:
    # Preserve upstream's warning/compiler behavior for checks without ASan.
    print('Host tests: selected Xcode compiler (no AddressSanitizer)', flush=True)
    raise SystemExit(subprocess.run([sys.executable, str(script), *sys.argv[2:]],
                     env=dict(os.environ, PYTHONUNBUFFERED='1')).returncode)
prefix = subprocess.check_output(['brew', '--prefix', 'llvm'], text=True, timeout=30).strip()
compiler = Path(prefix) / 'bin/clang'
version = subprocess.check_output([str(compiler), '--version'], text=True, timeout=30)
if int(re.search(r'clang version (\d+)', version)[1]) < 22:
    raise RuntimeError('Host sanitizer checks require LLVM 22 or newer on macOS 26')
print('Host tests: ' + version.splitlines()[0], flush=True)
with tempfile.TemporaryDirectory(prefix='bcd-host-test-cc-') as temporary:
    for name in ['cc', 'clang', 'clang++', 'c++']:
        Path(temporary, name).symlink_to(Path(prefix) / 'bin' / ('clang++' if '+' in name else 'clang'))
    environment = dict(os.environ, PATH=temporary + os.pathsep + os.environ['PATH'],
                       CC=str(compiler), CXX=str(Path(prefix) / 'bin/clang++'), PYTHONUNBUFFERED='1')
    result = subprocess.run([sys.executable, str(script), *sys.argv[2:]], env=environment)
    raise SystemExit(result.returncode)
