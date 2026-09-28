#!/usr/bin/env python3
"""Side-by-side images: web preview (left) | Flutter (right), same 390x844 @2x size -> compare/<name>.png
Also prints a mean absolute pixel difference per pair (lower = closer)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageStat
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
C = os.path.join(HERE, 'compare')
font = ImageFont.truetype(os.path.join(HERE, 'assets/junior/fonts/Nunito-900.ttf'), 34)
names = sorted(f[:-4] for f in os.listdir(os.path.join(C, 'web')) if f.endswith('.png') and os.path.exists(os.path.join(C, 'flutter', f)))
for n in names:
    a = Image.open(os.path.join(C, 'web', n + '.png')).convert('RGB')
    b = Image.open(os.path.join(C, 'flutter', n + '.png')).convert('RGB').resize(a.size)
    diff = sum(ImageStat.Stat(ImageChops.difference(a, b)).mean) / 3
    W, H = a.size
    out = Image.new('RGB', (W * 2 + 24, H + 64), (60, 50, 42))
    out.paste(a, (0, 64)); out.paste(b, (W + 24, 64))
    d = ImageDraw.Draw(out)
    d.text((20, 12), 'Web preview', font=font, fill=(255, 245, 230))
    d.text((W + 44, 12), 'Flutter (native)', font=font, fill=(255, 245, 230))
    d.text((W * 2 - 380, 12), n, font=font, fill=(255, 210, 160))
    out.save(os.path.join(C, n + '.png'), optimize=True)
    print(f'{n:18s} mean diff {diff:5.2f}')
