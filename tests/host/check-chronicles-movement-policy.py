#!/usr/bin/env python3
"""Portable semantic tests only. No game binding or UIKit/device claim."""
import os, pathlib, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as d:
    binary=str(pathlib.Path(d)/'chronicles-policy')
    subprocess.run([os.environ.get('CC','cc'),'-std=c11','-Wall','-Wextra','-Werror','-pedantic','-I',str(root/'app/Madeira'),str(root/'tests/host/chronicles_movement_policy_test.c'),'-lm','-o',binary],check=True)
    subprocess.run([binary],check=True)
