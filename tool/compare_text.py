#!/usr/bin/env python3
"""Compare text positions web vs Flutter: python3 tool/compare_text.py <screen> <lang>"""
import json, subprocess, sys, os
scr, lang = sys.argv[1], sys.argv[2]
web = json.loads(subprocess.check_output(['python3', 'tool/measure_web.py', scr, lang]))
env = dict(os.environ, MEASURE=scr, LANG_UI=lang, MEASURE_OUT='/workspace/tmp/measure_flutter.json')
subprocess.run(['flutter', 'test', 'test/measure_test.dart'], env=env, check=True, capture_output=True)
fl = json.load(open('/workspace/tmp/measure_flutter.json'))
used = set()
for t, x, y, h in web:
    m = next(((i, f) for i, f in enumerate(fl) if i not in used and f[0] == t), None)
    if not m: print(f'{t[:34]:36s} web y={y:6.1f} h={h:5.1f}   flutter: -'); continue
    used.add(m[0]); f = m[1]
    flag = '  <<' if abs(f[2] - y) > 1.5 or abs(f[3] - h) > 1.5 or abs(f[1] - x) > 1.5 else ''
    print(f'{t[:34]:36s} web x={x:5.1f} y={y:6.1f} h={h:5.1f} | fl x={f[1]:5.1f} y={f[2]:6.1f} h={f[3]:5.1f}{flag}')
