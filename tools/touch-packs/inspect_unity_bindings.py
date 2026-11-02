"""Bounded read-only extraction of serialized Unity InputBinding records, not a general asset decoder.

Usage: python tools/touch-packs/inspect_unity_bindings.py resources.assets --output bindings.json
Only records with a GUID, length-prefixed gamepad path and valid following strings are accepted.
Offsets are evidence for manual action-map review; no map/context or player-remap inference is made.
"""
import argparse
import hashlib
import json
import re
import struct
import uuid
from pathlib import Path

def string_at(data,offset):
    if offset<0 or offset+4>len(data):raise ValueError('String header outside input')
    size=struct.unpack_from('<I',data,offset)[0]
    end=offset+4+size
    if size>512 or end>len(data):raise ValueError('String bound exceeded')
    value=data[offset+4:end].decode('utf-8')
    if any(ord(c)<32 for c in value):raise ValueError('Control characters in metadata')
    return value,(end+3)&~3

def extract(data):
    if len(data)>8*1024*1024:raise ValueError('Asset exceeds 8 MiB extraction bound')
    result=[]
    for match in re.finditer(rb'<Gamepad>/[A-Za-z0-9/]+',data):
        offset=match.start()
        try:
            identifier,cursor=string_at(data,offset-44)
            uuid.UUID(identifier)
            if cursor!=offset-4:continue
            path,cursor=string_at(data,cursor)
            if path!=match.group().decode('ascii'):continue
            interactions,cursor=string_at(data,cursor);processors,cursor=string_at(data,cursor)
            groups,cursor=string_at(data,cursor);action,cursor=string_at(data,cursor)
            flags=struct.unpack_from('<I',data,cursor)[0]
            if 'Controller' not in groups.split(';') or not action or flags>15:continue
            result.append(dict(id=identifier,action=action,path=path,interactions=interactions,processors=processors,groups=groups,flags=flags,offset=offset))
        except (ValueError,UnicodeError,struct.error):continue
        if len(result)>256:raise ValueError('Too many input records')
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('asset',type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    if args.asset.stat().st_size>8*1024*1024:parser.error('Asset exceeds 8 MiB bound')
    data=args.asset.read_bytes();bindings=extract(data)
    if not bindings:parser.error('No validated serialized gamepad bindings found')
    result=dict(kind='Installed serialized binding defaults; active remaps and action maps require review',asset=args.asset.name,assetSHA256=hashlib.sha256(data).hexdigest(),bindings=bindings)
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(bindings=len(bindings),assetSHA256=result['assetSHA256'],sourceModified=False)))

if __name__=='__main__':main()
