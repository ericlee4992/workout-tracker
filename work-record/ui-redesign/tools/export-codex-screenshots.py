"""Copy xcresulttool attachments to stable, reviewable screenshot names."""
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parents[1]
raw = root / 'screenshots/codex-raw'
out = root / 'screenshots/codex'
out.mkdir(parents=True, exist_ok=True)
for test in json.loads((raw / 'manifest.json').read_text()):
    for attachment in test['attachments']:
        name = attachment['suggestedHumanReadableName'].split('_')[0]
        if name.startswith('codex-'):
            shutil.copy2(raw / attachment['exportedFileName'], out / f'{name}.png')
            print(out / f'{name}.png')
