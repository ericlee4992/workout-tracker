"""Muscle-map icons: a neutral body (BODY) with the family's muscle (MUSCLE) highlighted.
Writes chest/back/shoulders/arms/legs.svg (viewBox 48) with fill="BODY"/"MUSCLE" tokens and a sheet."""
BODY, MUSCLE = "#5B6472", "#FF6B7A"
torso = "M20 3 h8 a1 1 0 0 1 1 1 v4.5 c3 1 6.5 2.2 9.5 3.8 a6.5 6.5 0 0 1 3.2 5.4 l0.6 9.3 a3 3 0 0 1 -6 0.4 l-0.4 -5.7 c-0.6 -0.3 -1.1 -0.6 -1.7 -1 v11 c0 5 -0.5 8.8 -1.4 12.3 a2.5 2.5 0 0 1 -2.4 2 h-12.8 a2.5 2.5 0 0 1 -2.4 -2 C14.3 40.5 13.8 36.7 13.8 31.7 v-11 c-0.6 0.4 -1.1 0.7 -1.7 1 l-0.4 5.7 a3 3 0 0 1 -6 -0.4 l0.6 -9.3 a6.5 6.5 0 0 1 3.2 -5.4 c3 -1.6 6.5 -2.8 9.5 -3.8 V4 a1 1 0 0 1 1 -1 Z"
pecs = """<path fill="MUSCLE" d="M22.8 12.5 v10.5 c0 3.8 -2.4 6 -5.6 6 c-3.8 0 -6.4 -2.6 -6.4 -6.5 v-4.8 c0 -1.6 0.8 -2.7 2.2 -3.2 Z"/>
<path fill="MUSCLE" d="M25.2 12.5 v10.5 c0 3.8 2.4 6 5.6 6 c3.8 0 6.4 -2.6 6.4 -6.5 v-4.8 c0 -1.6 -0.8 -2.7 -2.2 -3.2 Z"/>"""
delts = """<path fill="MUSCLE" d="M6.3 19 c0 -5 3.5 -8.6 8.6 -9.4 l3 0.4 c0.6 2.8 0.4 5.6 -1.4 7.8 c-2.2 2.4 -6 2.8 -9.2 1.6 Z"/>
<path fill="MUSCLE" d="M41.7 19 c0 -5 -3.5 -8.6 -8.6 -9.4 l-3 0.4 c-0.6 2.8 -0.4 5.6 1.4 7.8 c2.2 2.4 6 2.8 9.2 1.6 Z"/>"""
lats = """<path fill="MUSCLE" d="M13.8 20.5 c3 0.2 6 -0.2 9 -1.2 v13.5 c-2.6 3.2 -5 5.2 -7.4 6.2 c-1.6 -5 -2 -12 -1.6 -18.5 Z"/>
<path fill="MUSCLE" d="M34.2 20.5 c-3 0.2 -6 -0.2 -9 -1.2 v13.5 c2.6 3.2 5 5.2 7.4 6.2 c1.6 -5 2 -12 1.6 -18.5 Z"/>
<path fill="MUSCLE" d="M24 9 c2.5 1 5 2 7.2 3.2 l-5.2 9 h-4 l-5.2 -9 c2.2 -1.2 4.7 -2.2 7.2 -3.2 Z"/>"""
arm_body = """<path fill="BODY" d="M4 30.5 a6.5 6.5 0 0 1 6.5 -6.5 c2 -6.5 7.5 -9.5 12.5 -8.5 c4.5 0.9 7.5 4.5 7.8 9.5 l1 0.2 l5.4 -15.4 a5 5 0 0 1 9.4 3.3 l-6.2 17.6 a8.5 8.5 0 0 1 -8 5.8 H10.5 A6.5 6.5 0 0 1 4 30.5 Z"/>
<circle fill="BODY" cx="38.3" cy="8.2" r="5.6"/>"""
bicep = """<path fill="MUSCLE" d="M12.2 25.2 c1.8 -5.2 6.2 -7.8 10.4 -7 c3.6 0.7 6 3.5 6.4 7.4 c-2.6 1.6 -5.5 2.4 -8.6 2.4 c-3 0 -5.8 -0.9 -8.2 -2.8 Z"/>"""
legs_body = "M13.5 3 h21 a2.5 2.5 0 0 1 2.5 2.5 v7 c0 3.5 -0.6 7 -1.2 10.5 v14 c0 2.5 0.3 4 0.8 5.5 h1.2 a1.5 1.5 0 0 1 1.5 1.5 v1 H29 a2 2 0 0 1 -2 -2 V30 c0 -3 -0.5 -6 -1.2 -9 h-3.6 c-0.7 3 -1.2 6 -1.2 9 v13 a2 2 0 0 1 -2 2 H8.7 v-1 a1.5 1.5 0 0 1 1.5 -1.5 h1.2 c0.5 -1.5 0.8 -3 0.8 -5.5 v-14 c-0.6 -3.5 -1.2 -7 -1.2 -10.5 v-7 a2.5 2.5 0 0 1 2.5 -2.5 Z"
quads = """<path fill="MUSCLE" d="M11.6 14 h8.6 c0.4 5 0.2 9 -1.2 12.5 c-0.8 2 -2.2 3 -3.4 3 c-1.4 0 -2.6 -1.2 -3.2 -3.5 c-1 -3.8 -1.2 -7.8 -0.8 -12 Z"/>
<path fill="MUSCLE" d="M36.4 14 h-8.6 c-0.4 5 -0.2 9 1.2 12.5 c0.8 2 2.2 3 3.4 3 c1.4 0 2.6 -1.2 3.2 -3.5 c1 -3.8 1.2 -7.8 0.8 -12 Z"/>"""
icons = {
 "chest": f'<path fill="BODY" d="{torso}"/>{pecs}',
 "back": f'<path fill="BODY" d="{torso}"/>{lats}',
 "shoulders": f'<path fill="BODY" d="{torso}"/>{delts}',
 "arms": f'{arm_body}{bicep}',
 "legs": f'<path fill="BODY" d="{legs_body}"/>{quads}',
}
for n, b in icons.items():
    open(f"{n}.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="1024" height="1024">{b}</svg>')
colours = {"chest":"#FF6B7A","back":"#4DA8FF","shoulders":"#2ED3BC","arms":"#B98CFF","legs":"#7FE06B"}
cells = ""
for i,(n,b) in enumerate(icons.items()):
    x = 20 + i*200
    body = b.replace("BODY", BODY).replace("MUSCLE", colours[n])
    cells += f'<g transform="translate({x},20)"><rect width="160" height="160" rx="32" fill="#171B21"/><g transform="translate(16,16) scale(2.6667)">{body}</g></g>'
    small = b.replace("BODY", BODY).replace("MUSCLE", colours[n])
    cells += f'<g transform="translate({x},200)"><rect width="48" height="48" rx="16" fill="#171B21"/><g transform="translate(4,4) scale(0.8333)">{small}</g></g>'
open("sheet.svg","w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="1020" height="270"><rect width="1020" height="270" fill="#0B0D10"/>{cells}</svg>')
print("written")
