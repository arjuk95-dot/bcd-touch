#!/usr/bin/env python3
"""Compile actual Foundation-only Queen policy; no UIKit/game validation."""
from pathlib import Path
import os, subprocess, tempfile
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='bcd-queens-') as d:
    d=Path(d)
    (d/'main.swift').write_text('import Foundation\ncheckQueensGesturePolicy()\n')
    subprocess.run([os.environ.get('SWIFTC','swiftc'),str(root/'app/Madeira/BCDQueensGesturePolicy.swift'),str(root/'tests/host/queens_gesture_checks.swift'),str(d/'main.swift'),'-o',str(d/'checks')],check=True)
    subprocess.run([str(d/'checks')],check=True)
