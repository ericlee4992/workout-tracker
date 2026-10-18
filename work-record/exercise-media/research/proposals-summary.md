# Animation proposals — Claude + Codex, combined (2026-10-18)

Sources: [claude-proposals.md](claude-proposals.md) (written first) and [codex-proposals.md](codex-proposals.md)
(independent, same brief). Claude re-checked Codex's machine-coverage lead: Gym visual lists "Lever Pendulum Squat
(plate loaded)" video ($10), "Lever Standing Viking Press (male)" video ($10) and "Lever Belt Squat" GIF ($3.60).

## Where they agree
- AI video is last: plausible-looking wrong form is a safety risk, machines are its weakest point.
- A code-drawn figure (Claude's A, Codex's 2.5D diagrams) is the credible **$0** route to one consistent look.
- Mixing wger photos, Everkinetic two-pose flips and unrelated clips is **not** a consistent library; keep them as
  supplementary at most.
- Custom exercises can only get an animation by explicitly choosing an already-reviewed movement — never guessed
  from the name. A new movement needs an authored or purchased asset.
- Shared build either way: one player for the exercise page and the workout pop-up, posters in lists, one loop at a
  time, Reduce Motion respected, a read-only media manifest keyed by seeded exercise UUIDs (no new SwiftData field
  for seeded media).

## Where they differ
- **Ranking:** Codex puts a **Gym visual pilot first** (closest to the Lyfta look; specialty machines exist), the
  drawn figure as the $0 fallback. Claude put the drawn figure first and Gym visual second.
- **Effort of the drawn figure:** Codex estimates **100–240 hours** (renderer, ~12–20 motion families, per-exercise
  overrides, machine diagrams, review). Claude had understated this.
- **Gym visual rights:** Codex found the general terms restrict "on-demand services" and keep removal/revocation
  powers — **written permission is needed before buying** (bundling, app-only R2 delivery, offline copies,
  conversion to MP4, continued use).
- **Catalog precision (Codex):** some seeded names don't define one movement — Rotator Cuff, Neck Machine,
  Multi-Hip, Machine Squat, Grip Trainer — and need a movement brief before any source can match them.
- **Codex's extra routes:** pay a demonstrator + studio to perform and animate our figure ($1–4k + 150–350 h);
  partner with an equipment maker or animation studio (uncertain, slow).

## Proposals to put to the user
1. **Gym visual, permission first** — email Gym visual for written confirmation, then a 10-item pilot of hard cases
   (bench, deadlift, seated row, lat pulldown, leg extension, pec deck, hack squat, pendulum squat, Viking press, a
   defined neck movement), checked on the phone and in Airplane Mode. Then the rest (~$81 GIFs / ~$540 video).
2. **Our own drawn figure ($0, much work)** — a 3-exercise prototype (leg extension, pec deck, pendulum squat) to
   judge whether a flat figure reads clearly; only then the full library.
3. **Free supplementary media only** — not a consistent library; muscle map + YouTube + user clips carry the rest.
4. (Not recommended) AI video trial; commissioning a performer; manufacturer partnership.

Meanwhile, the shared pieces (exercise-page media slot, workout pop-up, our own muscle maps, YouTube, user clips)
can be built, since every route needs them.

## Update — competitor study (2026-10-18)

[claude-competitor-study.md](claude-competitor-study.md) + [codex-competitor-study.md](codex-competitor-study.md):
apps either **license 3D renders** (Lyfta and Hevy file names carry Gym visual product codes; Liftosaur's public repo
documents buying Gym visual illustrations) or **film real trainers** (Fitbod, Alpha Progression, MuscleWiki, JEFIT,
StrengthLog, Gymshark). No AI or code-drawn demos were found in the sample. A second 3D vendor was found:
**Exercise Animatic** — human 3D artists, no AI, 2,600+ animation videos; licence (re-checked by Claude) permits
"commercial iOS and Android apps" including "free, paid and subscription-based", lifetime, resize/crop/transcode
allowed, no attribution; forbids redistribution/standalone downloads, sublicensing, AI training; **silent on offline
storage on devices** → ask in writing. Filmed-library vendors (ymove) and illustration vendors (WorkoutLabs) exist;
MuscleWiki's API forbids permanent storage (unsuitable).

**Updated recommendation:** ask **Gym visual and Exercise Animatic** the same short brief (exact matches for our
machine-heavy hard cases; written permission for app bundling, delivery from our server, offline storage on phones,
conversion to MP4), compare samples and terms, then pilot the better one. Lesson recorded: read a site's terms before
any automated access (JEFIT's and StrengthLog's forbid it; Boostcamp's forbid competitive research).
