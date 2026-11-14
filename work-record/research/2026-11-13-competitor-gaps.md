# What users of other fitness and nutrition apps complain about (2026-11-13)

Asked by the user to find what current apps lack or make uncomfortable, as input for the next updates. Three web
research passes (workout loggers; nutrition trackers; Korean and beginner apps) plus two idea passes (Claude and
Fable 5.2). **Evidence limits:** Reddit could not be read directly (blocked); Korean Google Play, Naver cafes and
community boards were mostly unreachable; several sources are competitors' blogs (weaker). Frequencies are judgements,
not counts. Treat single-source themes as hypotheses to test with users.

## Workout loggers (Strong, Hevy, Fitbod, JEFIT, Boostcamp, Apple)

| # | Theme | Signal | Notes / sources |
|---|---|---|---|
| 1 | Paywalls, free-tier caps, subscription price | strong | Strong free = 3 routines; Hevy caps routines/history; Fitbod $15.99/mo; Boostcamp moved graphs/rest timer behind paywall. Requests for one-time purchase. [Strong](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577), [Hevy reviews](https://justuseapp.com/en/app/1458862350/hevy-gym-trainingstagebuch/reviews) |
| 2 | Apple Watch / wearables weak | strong | Strong watch stops when phone is in the locker; JEFIT watch "flat out forget it"; Boostcamp none. Apple Fitness+ "Gym Strength" (watchOS 27.3 beta, Nov 2026) now logs reps/weight. [MacRumors](https://macrumors.com/2026/11/03/apple-fitness-plus-gym-strength) |
| 3 | Data loss, sync failures, bad imports | medium–strong | JEFIT unsynced workouts lost; Strong Android deletions (secondhand); Strong→Hevy import mixes kg/lb |
| 4 | Too many taps mid-workout | medium–strong | Hevy: wants "Next" between fields; JEFIT layers of clicks. Hevy's Live Activity can mark sets done from the Lock Screen (free). [Hevy help](https://help.hevyapp.com/hc/en-us/articles/35649846517399) |
| 5 | Progression suggestions missing or off | medium | Strong has none; Fitbod's are too high/low and repetitive |
| 6 | Machines differ between gyms | medium, rarely solved | Hevy's advice: duplicate the exercise per gym; gym tagging announced July 2026, not seen shipped; pulley ratios (2:1 vs 4:1) make stack numbers differ. [Hevy help](https://help.hevyapp.com/hc/en-us/articles/34264544382615-How-to-Create-Edit-and-Duplicate-Custom-Exercises-in-Hevy), [Hevy update](https://www.hevyapp.com/community-updates/july-26/) |
| 7 | Entering the real load (plates, bar, one vs two dumbbells) | medium | Hevy says single/double weights "raised a lot" |
| 8 | Bugs / lost features after redesigns | medium | JEFIT, Boostcamp, Gymshark |
| 9 | Rest timer | medium, mostly fixed by Live Activities | |
| 10 | Rigid exercise library | medium | |
| 11 | Social feed as default | weak, divisive | |

Requested, rarely delivered: per-gym, per-machine history and **machine setup notes (seat, pins)**; the real load
(pulley ratio, single/double dumbbells, any bar); a watch app that works without the phone; one-time pricing.

## Nutrition trackers (MyFitnessPal, MacroFactor, Cronometer, Lose It!, Yazio, Lifesum, Cal AI, Noom)

| # | Theme | Signal | Notes / sources |
|---|---|---|---|
| 1 | Basics paywalled (barcode, photo) | strong | MFP barcode Premium since 2022. [Slashdot](https://news.slashdot.org/story/22/08/25/1955238/myfitnesspal-paywalls-barcode-scanner-that-made-counting-calories-easy); review analysis: paywall 29% of 1–3★ ([unstar](https://unstar.app/blog/calorie-tracking-apps-ranked-1-star-reviews-2026)) |
| 2 | Wrong / duplicate database entries | strong | MFP "verified" still wrong ([forum](https://community.myfitnesspal.com/en/discussion/comment/43352806)) |
| 3 | Logging too slow; redesigns add taps | strong | UCL study of 58,881 posts ([UCL](https://www.ucl.ac.uk/news/2025/oct/emotional-strain-fitness-and-calorie-counting-apps-revealed)); MFP April 2026 redesign backlash ([PiunikaWeb](https://piunikaweb.com/2026/04/24/myfitnesspal-new-update-complaints/)) |
| 4 | AI photo estimates read low (hidden oil/sauce) | growing | NIH: 102 meals, ~250–345 kcal and ~30 g fat under per meal (preliminary) ([ScienceDaily](https://sciencedaily.com/releases/2026/07/260726015237.htm)) |
| 5 | Ads that interrupt logging | strong (free tiers) | |
| 6 | Billing / cancellation | strong | Noom, Cal AI, MacroFactor restore loops |
| 7 | Guilt, streaks, unsafe targets | moderate | 2025 systematic review ([Wallace et al.](https://uhra.herts.ac.uk/id/eprint/27021/2/wallace-et-al-2025-a-systematic-search-and-review-focusing-on-the-influence-of-health-tracking-technologies-on-eating.pdf)) |
| 8 | Eating out, delivery, home cooking | the hardest part of tracking | No delivery-order import found anywhere |
| 9 | Exercise calories double-counted | moderate | |
| 10 | Non-US foods | moderate (Korean evidence thin) | |
| 11 | Missed / partial days distort averages | few but real | Only MacroFactor handles it ([help](https://help.macrofactorapp.com/en/articles/241-what-is-partial-logging)) |

## Korean apps and gym culture; beginners

- **Machine weights don't carry over between gyms** — a Korean lifter at two gyms: squat machine 60 vs 22, "기록이
  의미가 없음" (the log is meaningless); fix suggested: log each machine separately. [Blind](https://www.teamblind.com/kr/post/%ED%97%AC%EC%8A%A4%EC%9E%A5-%EA%B8%B0%EA%B5%AC%EB%A7%88%EB%8B%A4-%EC%8B%A4%EB%AC%B4%EA%B2%8C%EA%B0%80-%EC%84%9C%EB%A1%9C-%EB%8B%A4%EB%A5%B8%EB%93%AF-kG7mOBw6) (one thread — a hypothesis to test)
- **Beginners don't know their gym's machines or how to use them; PT is expensive** (first package from ₩390,000).
  Public sports centres in Incheon/Busan put QR stickers on machines that open how-to videos. [Blind](https://www.teamblind.com/kr/post/헬스-처음-시작하는-헬린이-궁금한-게-많습니다-Bo7AYZNo), [Incheon](https://www.icjgss.or.kr/bbs/bbsMsgDetail.do?msg_seq=516&bcd=press&pgno=64)
- **AI routines generic / repetitive** (Planfit); substitute-exercise list is its most praised feature.
- **Lost data and broken sync** — the most consistent Korean theme (Planfit memos, 다이어트 카메라 resets, BurnFit Watch).
- **Too many taps** — BurnFit "select all sets"; Samsung Health machine sets not on the Watch.
- **Peak-hour queues** — "몇 세트 남으셨어요?"; advice: plan substitute machines.
- **Beginners: intimidation** (US survey of 1,069: intimidated members ~2× likelier to leave; [Athletech](https://athletechnews.com/survey-intimidation-overcrowding-top-reasons-for-gym-cancellations/)); **streaks backfire** after a break; **difficulty mismatch** (too hard, can't preview); too many choices.
- Surprising: Korean beginners rely on YouTube, free PT sessions and Naver cafes — they rarely mention apps.

## What this means for Stacked (Claude, 2026-11-13)

Already answered by Stacked: per-machine history across gyms (the core; competitors only starting — Hevy gym tagging
announced, Apple Gym Strength new); bar mode and dumbbells; Korean foods (N12); exercise calories never change the
goal; JSON/CSV export; prefilled one-tap sets; saving meals (N15).

Gaps the evidence supports, roughly by strength × fit:

1. **Machine setup memory** (seat, pins, pads; with a "hurt my elbow" note) — requested, rarely delivered; small.
2. **Stack / plate-number logging and pulley ratio** — Korean gyms, pulley differences; large (touches weight rules).
3. **Lock Screen set confirm** — Hevy has it free; parity for Stacked's own Live Activity; small–medium.
4. **"It's taken" swap at this gym** — peak-hour queues; Planfit's substitute list is its most praised feature; medium.
5. **Machine how-to card on scan + beginner first visit** — beginners' top fear; Korea uses QR stickers; medium–large.
6. **Progression nudge that knows the machine's stack steps** — small–medium.
7. **Nutrition: hidden-oil prompt on photo estimates** ("cooked with oil? sauce?") — NIH finding; small.
8. **Nutrition: share a delivery-app screenshot to log** — requested, found nowhere; small–medium.
9. **Partial days** — only MacroFactor; small.
10. **Forgiving weekly goal and easier comeback** instead of streaks — research-backed; small.
11. **Apple Watch app** — strong complaint theme and Apple now entering; written in Stacked, not shipped; large.

Positioning facts worth keeping: free basics (no paywalled barcode/photo), no ads, data that never disappears
(export, safety copy), no redesign that removes features.
