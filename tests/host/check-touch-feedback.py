#!/usr/bin/env python3
"""Portable production C policies and scoped source/provenance checks. No iOS claims."""
from pathlib import Path
import json,os,re,shutil,subprocess,tempfile

root=Path(__file__).resolve().parents[2]
def run(args,**kwargs):
 result=subprocess.run(args,cwd=root,text=True,capture_output=True,**kwargs)
 if result.returncode:raise RuntimeError(f'{args[0]} failed ({result.returncode}):\n{result.stdout}\n{result.stderr}')
 return result.stdout.strip()
cc=os.environ.get('CC') or ('cl' if os.name=='nt' else 'cc')
assert shutil.which(cc),f'C compiler unavailable: {cc}'
results=[]
scratch=root/'touch-evidence';scratch.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='bcd-feedback-',dir=scratch) as tmp:
 tmp=Path(tmp).resolve();assert tmp.is_relative_to(scratch.resolve())
 for name in ['table_policy_checks','table_relative_checks','table_native_utilities_checks','inscryption_mode_checks','inscryption_swipe_policy_checks','sulfur_sprint_policy_test']:
  exe=tmp/(name+('.exe' if os.name=='nt' else ''))
  src=root/'tests/host'/f'{name}.c'
  if Path(cc).stem.lower()=='cl':args=[cc,'/nologo','/std:c11','/W4','/WX','/I'+str(root/'app/Madeira'),str(src),f'/Fe:{exe}',f'/Fo:{tmp/name}.obj']
  else:args=[cc,'-std=c11','-Wall','-Wextra','-Werror','-I'+str(root/'app/Madeira'),str(src),'-lm','-o',str(exe)]
  run(args);output=run([str(exe)])
  results.append(dict(check=name,status='PASS',output=output));print('PASS:',name,output)
base='dbbb5bf538f30b46ebbcf18262e5a2e10710be97'
native=['wine','FEX','dxmt','madeira-dock','madeira-d3d12','build','app/Frameworks','app/Madeira/gl','app/Madeira/vulkan','app/Madeira/d3d12','app/Madeira/aarch64-windows','app/Madeira/arm64ec-windows','app/Madeira/i386-windows','app/Madeira/Assets.xcassets']
assert not run(['git','diff',base,'--name-only','--',*native]),'Native donor sources changed'
print('PASS: runtime/native/PE/GL/FEX/Dock sources and art unchanged from exact build655 source')
live=(root/'app/Madeira/BCDControlPackLive.swift').read_text(encoding='utf-8')
surface=(root/'app/Madeira/BCDControlPackSurface.swift').read_text(encoding='utf-8')
assert 'inscryptionExplore' not in live and 'switchInscryptionMode' not in live
assert 'BCDTableHoldEnd' in (root/'app/Madeira/BCDTableSurface.swift').read_text(encoding='utf-8')
assert 'a.evidence == "skald-shipped-input"' in surface
assert 'BCDApprovedDefaultRouting.hasPersonalChanges' in live
content=(root/'app/Madeira/ContentView.swift').read_text(encoding='utf-8')
# A selected pack must not synthesize WGI environment state. Explicit per-game
# choices still flow through the unchanged config bridge (including zero).
assert not re.search(r'\b(?:setenv|unsetenv)\s*\(\s*"MADEIRA_WGI_HOST_PADS"',content)
assert 'sulfurHostPad' not in content
assert 'sulfurEarlySlot' not in content
assert 'setLine(game, "env.MADEIRA_WGI_HOST_PADS", value == "1" ? "1" : "0")' in (root/'app/Madeira/BCDGamePageLive.swift').read_text(encoding='utf-8')
assert live.index('post(name:BCDTablePack.willChangeSession') < live.index('guard let entry else { BCDTablePad.shared.cancel()')
assert 'name: BCDTablePack.willChangeSession' in surface
assert 'clear();tablePointer?.accepting=false;self.pack=nil' in surface
assert 'store.tableInputEpoch.uuidString' in live
results.append(dict(check='wgi-no-implicit-process-state-and-synchronous-table-release-source-contract',status='PASS',scope='Source wiring only; Swift lifecycle/environment execution remains SDK-gated'))
pbx=(root/'app/Madeira.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert pbx.count('BCDAAA000000000000000A09 /* BCDTablePack.swift in Sources */')==2
assert 'fileRef = BCDAAA000000000000000B09' in pbx
results.append(dict(check='source-and-native-provenance',status='PASS'))
receipt=dict(base=base,checks=results,scope='Compiled production C policies plus source/provenance checks on Windows; not a Swift typecheck, UIKit dispatch run, IPA, guest game or phone test',pending=['Swift model/typecheck','UIKit pointer/button dispatch receipts','production GamepadInput serial publisher receipts','iOS glyph renderer previews','single app-only archive','coordinated phone install/game tests'])
out=root/'touch-evidence/feedback-local.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(receipt,indent=2))
print('PASS: scoped source checks; receipt:',out)
