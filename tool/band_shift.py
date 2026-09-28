#!/usr/bin/env python3
"""For each horizontal band of the web screenshot, find the vertical shift (device px) of the Flutter image that matches best.
Usage: python3 tool/band_shift.py home_en [band=60]"""
import sys, numpy as np
from PIL import Image
n = sys.argv[1]; band = int(sys.argv[2]) if len(sys.argv) > 2 else 60
a = np.asarray(Image.open(f'compare/web/{n}.png').convert('L'), dtype=np.float32)
b = np.asarray(Image.open(f'compare/flutter/{n}.png').convert('L'), dtype=np.float32)
H = a.shape[0]
for y in range(0, H - band, band):
    A = a[y:y + band]
    if A.std() < 3: continue
    best = None
    for dy in range(-30, 31):
        if y + dy < 0 or y + dy + band > H: continue
        d = np.abs(A - b[y + dy:y + dy + band]).mean()
        if best is None or d < best[1]: best = (dy, d)
    print(f'y={y:4d}  shift={best[0]:+3d}  diff={best[1]:5.1f}')
