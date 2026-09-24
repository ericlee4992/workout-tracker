"""Build a throwaway iPhone Simulator app; never touches the production target.

Run: python3 work-record/redesign-2026/iphone-prototype/build.py
Output: /tmp/wt-design-preview/DesignPreview.app
"""
from pathlib import Path
import plistlib
import subprocess
import urllib.request

here = Path(__file__).resolve().parent
output = Path('/tmp/wt-design-preview')
app = output / 'DesignPreview.app'
app.mkdir(parents=True, exist_ok=True)
fragment = (here.parent / 'visuals/workout-redesign.html').read_text()
# Reuse the exact supplied Lucide version from the visualizer, locally cached for offline use.
icons = output / 'lucide.js'
if not icons.exists():
    urllib.request.urlretrieve('https://unpkg.com/lucide@1.17.0/dist/umd/lucide.js', icons)
(app / 'lucide.js').write_bytes(icons.read_bytes())
fragment = fragment.replace("function go(screen){state.toast='';state.screen=screen;render();persist();}",
    "function go(screen){state.toast='';state.screen=screen;render();content.scrollTop=0;persist();}")
# Browser mock becomes the actual screen, with real device chrome and a pinned tab bar.
css = """
html,body{height:100%;margin:0;overflow:hidden;background:#111610;color-scheme:dark}
#wt-study{max-width:none;height:100%;margin:0}
#wt-study .study-bar,#wt-study>label,#wt-study>.jump,#wt-study .footer-note,
#wt-study .status,#wt-study .home-indicator{display:none}
#wt-study .phone{height:100%;display:flex;flex-direction:column;border:0;border-radius:0;overflow:hidden}
#wt-study .screen{min-height:0;flex:1;overflow-y:auto;overscroll-behavior:contain;-webkit-overflow-scrolling:touch;padding-top:10px}
#wt-study .nav{flex:none;margin-bottom:3px}
#wt-study .screen input,#wt-study .screen select,#wt-study .screen textarea{font-size:17px}
#wt-study .screen input[type=number]{font-size:20px}
#wt-study button{touch-action:manipulation;-webkit-tap-highlight-color:transparent}
"""
extra = """
const body=document.getElementById('wt-content'),picker=document.getElementById('wt-screen');
let previous=picker.value;
new MutationObserver(()=>{if(picker.value!==previous){body.scrollTop=0;previous=picker.value;}}).observe(body,{childList:true});
document.addEventListener('focusout',()=>{window.scrollTo(0,0);});
"""
(app / 'prototype.html').write_text(
    '<!doctype html><html><head><meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
    '<script src="lucide.js"></script></head><body>' + fragment +
    '<style>' + css + '</style><script>' + extra + '</script></body></html>')
info = {
    'CFBundleIdentifier': 'com.ericlee4992.workouttracker.designpreview',
    'CFBundleExecutable': 'DesignPreview', 'CFBundleName': 'DesignPreview',
    'CFBundleDisplayName': 'Design Preview', 'CFBundlePackageType': 'APPL',
    'CFBundleVersion': '1', 'CFBundleShortVersionString': '0.1',
    'MinimumOSVersion': '26.0', 'UIDeviceFamily': [1],
    'UILaunchScreen': {}, 'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'],
    'UIApplicationSceneManifest': {'UIApplicationSupportsMultipleScenes': False,
        'UISceneConfigurations': {}},
}
with (app / 'Info.plist').open('wb') as f:
    plistlib.dump(info, f)
sdk = subprocess.check_output(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], text=True).strip()
subprocess.run(['xcrun', 'swiftc', '-sdk', sdk, '-target', 'arm64-apple-ios26.0-simulator',
    '-swift-version', '5', '-parse-as-library', '-framework', 'UIKit', '-framework', 'WebKit',
    str(here / 'PreviewApp.swift'), '-o', str(app / 'DesignPreview')], check=True)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
print(app)
