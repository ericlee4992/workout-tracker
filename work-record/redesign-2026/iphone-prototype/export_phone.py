"""Export the design study as a directly interactive, phone-sized browser preview."""
from pathlib import Path
import urllib.request
base=Path(__file__).resolve().parent.parent
s=(base/'visuals/workout-redesign.html').read_text()
s=s.replace("function go(screen){state.toast='';state.screen=screen;render();persist();}","function go(screen){state.toast='';state.screen=screen;render();content.scrollTop=0;persist();}")
cache=Path('/tmp/wt-design-preview/lucide.js')
if not cache.exists():
    cache.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve('https://unpkg.com/lucide@1.17.0/dist/umd/lucide.js', cache)
icons=cache.read_text()
style='''
html,body{margin:0;background:#20241e;color:#f2f5ec;color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,sans-serif}
body{padding:18px 12px}#wt-study{max-width:410px}
#wt-study .study-bar{font-size:11px;padding-bottom:14px}
#wt-study .phone{height:min(840px,calc(100dvh - 120px));min-height:550px;display:flex;flex-direction:column;border:2px solid #505948;border-radius:42px;box-shadow:0 22px 70px #0007}
#wt-study .screen{flex:1;overflow:auto;min-height:0;overscroll-behavior:contain;scrollbar-width:none}
#wt-study .screen::-webkit-scrollbar{display:none}
#wt-study .nav{flex:none;margin-bottom:2px}
#wt-study .status{flex:none;padding-top:16px}
#wt-study .home-indicator{flex:none;margin:10px auto 8px}
#wt-study>.eyebrow{display:none}#wt-study>.jump{font-size:13px;margin-bottom:10px;min-height:38px}
#wt-study .footer-note{font-size:12px;padding:13px 0;color:#c7cdbf}
#wt-study .status .island{background:#050604}
@media(max-width:430px){body{padding:0}#wt-study{max-width:none}#wt-study .study-bar{padding:8px 12px}#wt-study>.jump{width:calc(100% - 24px);margin:0 12px 8px}#wt-study .phone{height:calc(100dvh - 110px);min-height:470px;border-radius:30px}#wt-study .footer-note{padding:7px}}
'''
footer='''
const panel=document.getElementById('wt-content'),screenSelect=document.getElementById('wt-screen');let old=screenSelect.value;
new MutationObserver(()=>{if(screenSelect.value!==old){panel.scrollTop=0;old=screenSelect.value;}}).observe(panel,{childList:true});
document.querySelector('.footer-note').textContent='Click to tap · scroll inside the phone · type into fields';
'''
out='<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Interactive iPhone · Workout Design</title><script>'+icons+'</script></head><body>'+s+'<style>'+style+'</style><script>'+footer+'</script></body></html>'
(base/'visuals/iphone-interactive.html').write_text(out)
