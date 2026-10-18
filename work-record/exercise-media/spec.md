# Exercise library + form video — spec (draft)

Status: draft — sources being checked (ticket 02); decisions below are open until the user answers.
Branch: `ericlee4992/beta-18-exercise-media` off `main` `1f0e040`.

## The request (the user, 2026-10-18)

> Build the exercise library + form-video feature.
> Step 1 — Study the reference UX with REA: the exercise detail screen in Lyfta: Gym Workout Tracker Log.
> Step 2 — Rebuild it as our own. Exercise media can come from sources we're licensed to use:
> - wger (wger.de REST API, CC-BY-SA 4.0): primary source for metadata, muscles, equipment, images. Video coverage is
>   sparse.
> - ExerciseDB: self-hostable open-source V1. Check the current license/terms of the V2 API and report back before
>   relying on it.
> - User-recorded clips: a first-class media type, stored locally.
> - YouTube embeds (official iframe player only): online-only fallback. Never download or re-host YouTube files.
>
> During workouts, when user clicks the exercise (or some button on exercise), a window should pop up that shows the
> form video. Also in the exercises tab I should be able to see the animations of the exercises.

## What exists today

- 90 seeded exercises (`Resources/SeedCatalog.json`, reconciled by version, D24) plus the user's custom exercises
  (`Exercise`: name, load type, equipment tags, `muscleGroup` — one coarse group, e.g. "Chest").
- The Exercises tab (`Features/Exercises/ExercisesView.swift`) and each exercise's page
  (`ExerciseDetailView.swift`: identity, the user's numbers, best set, records, setup, machines, recent workouts).
- The live workout's exercise cards (`Features/ActiveWorkout/`); a card's title has no media action today.
- Offline-first app; a Cloudflare Worker + D1 + R2 server we own (accounts, AI, feedback); a public privacy page
  (`/privacy`, D61) that names every data flow.

## Rules this feature must keep (from AGENTS/DECISIONS)

- Licensed media only, with the attribution each licence requires shown in the app; YouTube only through the
  official embedded player, never downloaded or re-hosted (the user's rule).
- No third-party runtime code in the app (a WKWebView with YouTube's iframe player is web content, not an SDK — to
  confirm in review).
- **User clips change what the phone stores** → a store-format change: Gate S (DEVELOPMENT → backup) before it ships
  to the phone, and ticket 11 (automatic safety copy before a store-changing update, deferred "until the first
  stored-format change") becomes due. Clips must survive relaunch; deleting an exercise must say what happens to its
  clips; export must say whether clips are included.
- Any new network flow (fetching media, YouTube) is a privacy-policy change (D61) and an App Privacy check before
  testers get it.

## Open decisions (to ask once ticket 02 reports)

1. **Primary media source** for the 90 seeded exercises — depends on ticket 02's licence findings and on whether the
   user will pay for a licensed animation set if the free sources cannot cover "animations".
2. **Where media lives**: bundled in the app (size), downloaded on demand and cached (from the source or our R2), or
   streamed. Offline behaviour in the gym.
3. **Custom exercises**: no media / user clip / user-chosen YouTube link / pick a seeded exercise's media.
4. **In-workout entry point**: tap the exercise's name on its card, or a small "form" button; sheet or full-screen.
5. **Exercises tab**: still frame per row (motion on the detail page) or animated rows.
6. **Recording clips**: in-app camera vs. pick from Photos; length cap; trim; per exercise or per variation (D36).

## Tickets

1. [01 Reference UX study (REA)](issues/01-reference-ux-study.md) — done for the web library.
2. [02 Media sources and licences](issues/02-media-licensing.md) — in progress.
3. Further tickets (data mapping, media hero on the exercise page, in-workout sheet, Exercises tab media, user clips,
   YouTube fallback, privacy/attribution) are drafted after the decisions above.
