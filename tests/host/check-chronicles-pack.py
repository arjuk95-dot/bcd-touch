#!/usr/bin/env python3
"""Compile actual portable model/factory; no copied gameplay code or device claim."""
import os,pathlib,subprocess,tempfile
r=pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='bcd-chronicles-') as tmp:
    exe=pathlib.Path(tmp)/'checks'
    sources=['app/Madeira/BCDMouseJoystick.swift','app/Madeira/BCDControlPack.swift','app/Madeira/BCDControlPackAuthoring.swift','app/Madeira/BCDChroniclesPack.swift','tests/host/chronicles_pack_checks.swift']
    subprocess.run([os.environ.get('SWIFTC','swiftc'),'-parse-as-library','-swift-version','5',*map(lambda x:str(r/x),sources),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
