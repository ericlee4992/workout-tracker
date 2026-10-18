# 02 — Media sources and licences

Type: research
Status: resolved (2026-10-18) — full report: [research/media-licensing.md](../research/media-licensing.md)
Blocked by: —

## Question

For wger, ExerciseDB V1 (self-hosted), ExerciseDB V2 (hosted API), YouTube embeds, and any other well-licensed set:
what may a commercial App Store app do with each source's metadata and media (display, bundle, cache, re-host on our
server, attribution, share-alike), and what is each one's video/animation coverage? The user asked specifically for
**ExerciseDB V2's current licence and terms to be reported back before relying on it**.

Lead from ticket 01 (an observation, not proof): Lyfta plays MP4s from a path named `GymvisualMP4/…`, suggesting
licensed Gymvisual animations; the numeric ids resemble ExerciseDB's. The research checks where ExerciseDB's media
comes from and what Gymvisual licenses.

## Answer

Full report with citations: [research/media-licensing.md](../research/media-licensing.md) (a research agent, primary
sources, 2026-10-18). Claude re-checked the decisive facts itself:
- wger API (2026-10-18): 932 exercises, 383 images, 78 videos — all 78 videos CC-BY-SA 4 by one author ("Goulart"),
  covering 46 exercises.
- AscendAPI caching guide: "If your plan does not permit caching, you must not store any data returned by the API."
- Gym visual licence page: media "may be used … to illustrate and visually enhance: Android or iOS mobile application
  (apps)"; "granted in perpetuity"; may NOT be used "to resell or redistribute", "to assign rights to third parties",
  "to make available on a website for download".

**Per source.**
- **wger — usable.** Commercial use, bundling, caching and re-hosting are allowed; each item needs a credit (title,
  author, source, licence); our edits/translations of wger text or images must be CC BY-SA; our code is unaffected.
  **Coverage is thin**: images on 279 of 932 exercises (5 animated GIFs), video on 46. Against **our 90 seeded
  exercises** (fuzzy name match, upper bound — some matches are wrong): ~71 named, **~30 with an image, ~5–8 with a
  video**; styles mixed (photo, line, 3D, some AI-generated).
- **ExerciseDB V1 — not for us.** The repo says AGPL, but the provider's own V1 docs say "Non-commercial use only" and
  require credit; the media appear to be Gym visual's with no licence shown.
- **ExerciseDB V2 — blocked (the user asked to hear this before relying on it).** Terms forbid storing anything on
  devices or servers, cap caching at 1 hour, require fresh fetches for every use, and on cancellation require us to
  "Discontinue any applications or services that utilize the API". $100/month for unwatermarked media. No offline
  gym use, lock-in for the app's lifetime.
- **Gym visual — the clean route to the 3D animated look** (very likely the upstream of ExerciseDB's and Lyfta's
  media). Per-item, perpetual, iOS apps explicitly allowed, no attribution required. GIF $3.60 (≈$0.90 each after 10
  in the cart), video $10 (≈$6 each after 5). Purchased files must stay **out of the public repo** (served to our app
  from private storage / bundled at build time from a private source). Ask Gym visual to confirm server delivery.
- **YouTube embeds — allowed with obligations.** Player ≥200×200, nothing drawn over it, our bundle ID as Referer,
  no download/offline, **never charge users to watch embeds** (matters for a future subscription), privacy policy must
  link Google's and our terms YouTube's, owners can disable embedding at any time (handle errors 100/101/150/153).
- **Muscle maps.** wger's muscle SVGs come from Wikimedia Commons "Muscular system" (Termininja, CC BY-SA 3.0):
  usable with credit, recolours stay BY-SA. Alternatives: Häggström's public-domain diagrams; MIT body-highlighter
  SVGs (art provenance undocumented); or our own drawings.
- **Others:** Everkinetic (CC BY-SA 4.0, ~550 exercises, two-frame line drawings — a "start/end" pose pair);
  free-exercise-db's photos have no documented provenance (avoid). No free, well-sourced video library exists.
