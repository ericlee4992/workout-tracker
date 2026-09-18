#!/usr/bin/env python3
"""Export native design captures and omit identical scroll images from the gallery.
Usage: python3 work-record/cardio-design/export-captures.py <xcresult-path>
"""
from pathlib import Path
import hashlib, json, re, shutil, subprocess, sys
base = Path(__file__).resolve().parent
bundle = Path(sys.argv[1]).resolve()
raw = bundle.parent / (bundle.stem + '-exported')
subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle), '--output-path', str(raw)], check=True, stdout=subprocess.DEVNULL)

def copy(value):
    if isinstance(value, dict):
        if 'exportedFileName' in value:
            name = value.get('suggestedHumanReadableName', '').split('_')[0]
            if name.startswith('cardio-'):
                shutil.copy(raw / value['exportedFileName'], base / 'screenshots' / (name + '.png'))
        for item in value.values(): copy(item)
    elif isinstance(value, list):
        for item in value: copy(item)
copy(json.loads((raw / 'manifest.json').read_text()))
index = {}
for screen, variant in [('mixed', 'A'), ('mixed', 'B'), ('mixed', 'C')] + [(s, 'A') for s in ['start','picker','gym','outdoor','summary']]:
    for size in ['default', 'axl']:
        key = f'{screen}-{variant}-{size}'
        seen = set(); index[key] = []
        for suffix in ['', '-scroll1', '-scroll2']:
            path = base / 'screenshots' / f'cardio-{key}{suffix}.png'
            if not path.exists(): continue
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if digest in seen: continue
            seen.add(digest); index[key].append(suffix)
gallery = base / 'gallery.html'
text = re.sub(r'const captureSets = .*?;', 'const captureSets = ' + json.dumps(index) + ';', gallery.read_text(), count=1)
gallery.write_text(text)
print(f'{sum(map(len,index.values()))} distinct views across {len(index)} screen/size pairs')
