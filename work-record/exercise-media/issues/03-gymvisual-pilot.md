# 03 — Gym visual pilot: 10 hard exercises

Type: task
Status: list ready (2026-10-18) — the user buys; Claude then converts, bundles privately and shows them in the app
Blocked by: —

## Why these ten

The hardest cases of our 90 (machines, specific mechanisms) plus two free-weight anchors. If these look right on the
phone, the rest of the library is low risk. Matches were chosen against our catalog's equipment tags
(`SeedCatalog.json`), not by name alone. Gym visual allowed our research agent to browse its site (the user,
2026-10-18); product details read from gymvisual.com on 2026-10-18.

## The list

All animated GIFs unless noted; male versions; **one style for all items** (the page offers "Basic grey" or
"Full color" at the same price — pick the one that matches the Lyfta look you liked, and use it for every item).
Each GIF purchase includes four sizes: 180, 360, 720, 1080 px.

| # | Our exercise (tags) | Gym visual product | Code | Link | Alternatives / notes |
|---|---|---|---|---|---|
| 1 | Bench Press (barbell) | **Barbell Bench Press** | 002513 | [1519](https://gymvisual.com/animated-gifs/1519-barbell-bench-press.html) | — |
| 2 | Deadlift (barbell, machine) | **Barbell Deadlift** | 003213 | [1526](https://gymvisual.com/animated-gifs/1526-barbell-deadlift.html) | — |
| 3 | Seated Row (machine, cable) | **Cable Low Seated Row** | 018013 | [1673](https://gymvisual.com/animated-gifs/1673-cable-low-seated-row.html) | Lever Seated Row (#3120) if your gym's is a plate/lever machine |
| 4 | Lat Pulldown (machine, cable) | **Cable Bar Lateral Pulldown** | 015013 | [1643](https://gymvisual.com/animated-gifs/1643-cable-bar-lateral-pulldown.html) | wide-grip bar; close-grip version #2516 |
| 5 | Leg Extension (machine) | **Lever Leg Extension** | 058513 | [2082](https://gymvisual.com/animated-gifs/2082-lever-leg-extension.html) | plate-loaded version #4577 |
| 6 | Chest Fly (Pec Deck) (machine) | **Lever Pec Deck Fly** | 103013 | [2499](https://gymvisual.com/animated-gifs/2499-lever-pec-deck-fly.html) | arm-pad pec deck; handle version "Lever Seated Fly" #2093 |
| 7 | Hack Squat (machine) | **Sled Hack Squat** | 074313 | [2226](https://gymvisual.com/animated-gifs/2226-sled-hack-squat.html) | classic 45° sled; "Lever Linear Hack Squat" #17730 |
| 8 | Pendulum Squat (machine) | **Lever Pendulum Squat (plate loaded)** | 495113 | [12391](https://gymvisual.com/animated-gifs/12391-lever-pendulum-squat-plate-loaded.html) | — |
| 9 | Neck Machine (machine) | **Lever Neck Extension (plate loaded)** | 228213 | [4785](https://gymvisual.com/animated-gifs/4785-lever-neck-extension-plate-loaded.html) | our name is ambiguous (a 4-way neck machine does extension, flexion, side flexion); left/right side flexion #4786/#4787 exist |
| 10 | Viking Press (machine) | **Lever Standing Viking Press (male) — VIDEO only** | — | [video 19892](https://gymvisual.com/videos/19892-lever-standing-viking-press-male.html) | no GIF of the machine version; the GIF "Strongman Viking Press" (#6687) is a different implement — not a match |

## Cost (from the product pages)

- GIF list price $3.60; **75% off once 5 or more different items are in the cart** → $0.90 each.
  Items 1–9: 9 × $0.90 ≈ **$8.10**.
- Item 10 is a video: $10 (the video discount starts at 5 videos). Pilot total ≈ **$18** before tax.
- Cheaper alternative: drop the Viking press from the pilot (9 GIFs ≈ $8) and decide it later.

## After purchase (Claude)

1. Keep the originals **outside the repository** (e.g. a private folder on the Mac; never committed — public repo).
2. Convert to small looping MP4/HEVC at an app size (licence allows modify/reproduce), with a poster frame.
3. A build step copies them into the app from the private folder; builds without it show no clip.
4. Show them in a prototype of the exercise page and the workout pop-up on the Simulator, then on the phone
   (including Airplane Mode). The user checks each one for correct form and the right machine.
