"""One-time fork project/CI setup, repeatable from the pinned upstream checkout."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'app/Madeira.xcodeproj/project.pbxproj'
s=p.read_text(encoding='utf-8')
names=['BCDMouseJoystick','BCDControlPack','BCDControlPackLive','BCDControlPackSurface']
for i,name in enumerate(names):
    build=f'BCDT000000000000000000A{i:02X}'
    ref=f'BCDT000000000000000000B{i:02X}'
    if f'{name}.swift in Sources' not in s:
        s=s.replace('/* Begin PBXBuildFile section */',f'/* Begin PBXBuildFile section */\n\t\t{build} /* {name}.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ref}; }};')
        s=s.replace('/* Begin PBXFileReference section */',f'/* Begin PBXFileReference section */\n\t\t{ref} /* {name}.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}.swift; sourceTree = "<group>"; }};')
        # Follow the existing GamepadInput references into the app group and compilation phase only.
        lines=s.splitlines(True)
        for n,line in enumerate(lines):
            if '/* GamepadInput.swift */,' in line: lines[n]=line+f'\t\t\t\t{ref} /* {name}.swift */,\n'
            if '/* GamepadInput.swift in Sources */,' in line: lines[n]=line+f'\t\t\t\t{build} /* {name}.swift in Sources */,\n'
        s=''.join(lines)
s=s.replace('com.thebcd69.bcd.MemoryHost','com.arjunkl.bcdtouch.MemoryHost').replace('MADEIRA_BUNDLE_IDENTIFIER = com.thebcd69.bcd;', 'MADEIRA_BUNDLE_IDENTIFIER = com.arjunkl.bcdtouch;')
p.write_text(s)
p=ROOT/'app/Madeira/Info.plist';s=p.read_text(encoding='utf-8').replace('<string>BCD</string>','<string>BCD Touch Lab</string>').replace('<string>bcd</string>','<string>bcdtouchlab</string>')
# LAN worker pairing; no global arbitrary-load exception.
if '<key>NSLocalNetworkUsageDescription</key>' not in s:
    s=s.replace('<dict>','<dict>\n\t<key>NSLocalNetworkUsageDescription</key><string>Connect to your desktop control-pack worker.</string>',1)
    if '<key>NSAppTransportSecurity</key>' not in s:
        s=s.replace('<dict>','<dict>\n\t<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>',1)
p.write_text(s)
p=ROOT/'tools/ui-preview.py';s=p.read_text(encoding='utf-8')
if '"BCDControlPackLive.swift"' not in s: s=s.replace('ENGINE_BOUND |= {"BCDTurboLive.swift"','ENGINE_BOUND |= {"BCDControlPackLive.swift", "BCDControlPackSurface.swift", "BCDTurboLive.swift"')
p.write_text(s)
print('Configured separate BCD Touch Lab identity and source membership')
