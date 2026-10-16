# Stacked

**Know your numbers. Every machine. Every gym.**

Stacked is an iPhone workout logger that knows which machine you're on. It is in a **TestFlight beta**
for invited testers; an App Store release is planned after it. (The repository and Xcode project keep the
working name, Workout Tracker.)

I move around a lot, and every gym has different equipment. In other trackers I had to log
everything under a generic "chest press" or "shoulder press", so a 60 kg set on one gym's
plate-loaded press and a 60 kg set on another's cable machine looked identical in my history
and nothing was comparable. Stacked anchors every set to a specific machine at a specific gym.
Previous performance, prefilled sets and records are per machine first, per equipment model
second, and per exercise only as a last resort — each layer labelled so you know what you're
comparing against.

<!-- Screenshots in docs/readme/: Floodlight capture UI tests (dark, default text size, built-in sample data),
taken 2026-10-15 and halved in size. Retake them when a shown screen changes visibly (AGENTS.md). -->
<p>
<img src="docs/readme/workout.png" width="150" alt="The Workout tab: gym, start buttons, this week and templates">
<img src="docs/readme/live-workout.png" width="150" alt="Logging sets during a workout, with the rest timer">
<img src="docs/readme/gyms.png" width="150" alt="A gym and its machines, with Scan Machine">
<img src="docs/readme/cardio.png" width="150" alt="An indoor run in progress">
<img src="docs/readme/history.png" width="150" alt="History: the month and recent workouts">
<img src="docs/readme/ai-routine.png" width="150" alt="Ask AI's suggested week of templates">
</p>

## What it does

- **Gyms and machines.** Each gym has its own machines. Adding one can read its name plate on
  the phone and match it against a seeded catalog of 1,877 equipment models from 23
  manufacturers.
- **Fast logging.** Set rows arrive prefilled from your last session on that machine;
  confirming an untouched row is one tap. Weights keep the unit you entered, kg or lb, and
  are never silently converted. Supersets, presets (grips, stances), and the workout with its
  rest timer on the Lock Screen.
- **Cardio.** Indoor machines and outdoor walks, runs and rides with a GPS route — on their
  own or in the same workout as lifting.
- **Templates.** Save a workout as a plan and start it at any gym; each exercise resolves to
  the machine you last used there.
- **Heart rate and Apple Health.** Live bpm from AirPods or an Apple Watch, zones, calories
  and a heart-rate rest timer; workouts are saved to Apple Health.
- **History.** A calendar, per-session detail with editing, records, progress charts per
  exercise and variation, and CSV or JSON export of everything.
- **Optional account and AI.** Sign in with Apple or Google to identify a machine from a
  photo, get exercise suggestions for a new machine, or have Ask AI build a week of
  templates from your training profile. Each AI feature asks first and has a daily limit.
- **Onboarding and feedback.** A guided tour of the real app on sample data, and
  Settings → Send Feedback with an optional screenshot.

## Privacy

Your workouts stay on your iPhone; the server never receives them. The account, AI requests
and feedback go through a small server of mine. The
[privacy policy](https://stacked-server.stacked-server.workers.dev/privacy) says exactly what is
kept and for how long; [support](https://stacked-server.stacked-server.workers.dev/support).

## Building

Requires Xcode 26 or later and iOS 26. The simulator build needs no signing:

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug build
```

For a real phone, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` with your own
team ID and bundle-ID prefix, then run `./scripts/install-on-device.sh`. Unit tests:

```sh
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=WT-iPhone' \
  -only-testing:WorkoutTrackerTests
```

The server is a Cloudflare Worker (TypeScript, D1, R2): `cd server && npm install && npm test`.
Setup, secrets and deployment are in [`server/README.md`](server/README.md); secrets are never
in this repository.

## Layout

| Folder | What it holds |
|---|---|
| `WorkoutTracker/` | The app: `App/`, `Domain/` (SwiftData models and pure logic), `Features/` (one folder per area: workout, cardio, gyms, exercises, templates, history, settings, account, onboarding), `Resources/` (the seeded catalog) |
| `WorkoutTrackerTests/`, `WorkoutTrackerUITests/` | Unit tests (Swift Testing) and end-to-end UI tests (XCTest) |
| `WorkoutTrackerWidget/` | The Live Activity: the running workout and its rest timer on the Lock Screen |
| `WorkoutTrackerWatch/` | A placeholder Watch target; it has never been built or run |
| `server/` | The backend: accounts (Apple, Google), the AI proxy with daily limits, feedback, the privacy and support pages |
| `Config/`, `scripts/` | Build settings (`Local.xcconfig` is yours and git-ignored), catalog generation, device install, the secret scanner |
| `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md` | Shared agent workflow, Claude's import of it, the domain glossary |
| `docs/` | `SPEC.md` (product), `DECISIONS.md` (why), `STATE.md` (current work), `DEVELOPMENT.md` (runbook), `archive/` (preserved handoffs) |
| `work-record/` | Every ticket with its acceptance criteria and resolution, every cross-review, and the screenshots each ticket was judged on |
| `graft/` | A generated map of the code for agents |

## How it was built

Solo, with AI coding agents under a workflow described in [`AGENTS.md`](AGENTS.md): work is
split into numbered tickets; each ticket is built by one agent and cross-reviewed by a
different one (Claude and Codex) until it is clear; screens go through a written design
process with captures at the default and accessibility text sizes; and tests are chosen by
what a change can affect ([verification scope](docs/DEVELOPMENT.md#verification-scope)), with the
full UI suite for broad changes. The decision log and the work record are the paper trail.

**Status:** TestFlight beta for invited testers (October 2026); App Store release later. The
current work is in [`docs/STATE.md`](docs/STATE.md).
