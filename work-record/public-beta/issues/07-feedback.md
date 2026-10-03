# 07 — Feedback section

Type: task
Status: in progress — form mocked (captures in `../captures/07/`), awaiting the user's approval; server next
Blocked by: — (03's server half is merged; feedback works signed out, so 03's app half is not needed)
Implementer: Claude; Reviewer: Codex (as for 01–03).
Branch: `ericlee4992/beta-07-feedback` off `main`.
Spec: [spec.md](../spec.md) → *Feedback*. Decision: D60.

## Goal

Testers send feedback from inside the app; the developer can read it.

## Scope

- **Settings → Send Feedback:** category (Bug / Idea / Other), message (required, up to 4,000 characters),
  optional screenshot from Photos, and a visible footer of what is attached: app version and build, iOS version,
  phone model, and the account when signed in. A line states what is sent and to whom. Works signed out.
- **Server:** `POST /v1/feedback` stores the text and metadata in D1 and the screenshot in R2 (PNG/JPEG, up to
  5 MB). Signed-out submissions limited to 10 per day per hashed IP. Account deletion deletes the account's
  feedback and screenshots.
- A `server/scripts` command (and README steps) to list recent feedback and fetch a screenshot.
- TestFlight's built-in feedback stays on; nothing to build for it.

## Design (ios-design skill, steps 1–4)

**Job, state, bold element.** *In the compose state this sheet exists so a tester can describe a problem or an idea
and send it in one tap; the eye lands on the message field* (the largest block, first under the category). The
runner-up is **Send**, the one accent-filled command, top-trailing in the header as in every staged-edit sheet
(`SheetHeader`), disabled until the message has text. *In the sent state it exists so the tester knows it arrived;
the eye lands on "Sent"*; Done is the only command (glass, not accent).

**Where.** Settings → Help → **Send Feedback** (a `LookRow` under Show Tour). A sheet: composing is one task with a
commit (Cancel / Send); a non-empty draft cannot be swiped away by accident (`interactiveDismissDisabled`).

```
Compose (Default)                       Sent
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ (Cancel)   Feedback   [Send] │ chrome │                       (Done) │
│ [ Bug |  Idea  |  Other    ] │ pills  │                              │
│ ┌──────────────────────────┐ │        │             (✓)              │
│ │ What happened, or what   │ │ ← bold │            Sent              │ ← bold
│ │ would you change?        │ │ largest│ Thanks — every message is    │
│ │                          │ │        │ read.                        │
│ └──────────────────────────┘ │        │                              │
│ ┌ 🖼 Add Screenshot ────────┐ │ row    │                              │
│ Sent with it                 │        │                              │
│ ┌ App        Stacked 0.1.0 (1)│ list   │                              │
│ │ iOS                   27.0 │ 4 rows │                              │
│ │ iPhone          iPhone16,2 │        │                              │
│ └ Account     Not signed in ┘ │        │                              │
│ 🔒 Goes only to Stacked's developer.  │                              │
└──────────────────────────────┘       └──────────────────────────────┘
```

With a screenshot, the Add row becomes a tile: thumbnail, "Screenshot", "JPEG · 33 KB · photo details removed",
**Remove** (destructive colour, plain). At AccessibilityL the detail rows stack label over value, the screenshot
tile stacks, and the header title moves under the buttons (`reflowsTitle`). A counter ("3,612 of 4,000") appears
only from 3,500 characters; input stops at 4,000. No autofocus: the tester sees everything that will be sent
before the keyboard covers it.

**Screenshot handling.** `PhotosPicker` (no Photos permission needed; the picker runs out of process). The image is
decoded and re-encoded as JPEG (quality 0.85, stepping down to stay ≤ 5 MB), so no EXIF/location is sent (D56's
rule for photos). What the tile shows is exactly what is sent.

**Proposed copy (every string is the user's decision):** Settings row **Send Feedback**; sheet title **Feedback**;
**Cancel / Send / Sending… / Done**; categories **Bug / Idea / Other** (default Bug); placeholder **What happened,
or what would you change?**; **Add Screenshot**, **Screenshot**, **Remove**; section **Sent with it** with
**App / iOS / iPhone / Account** and **Not signed in**; **Goes only to Stacked's developer.**; **Sent**, **Thanks —
every message is read.** Errors: **Couldn't send. Check your connection and try again.**; **Couldn't read that
image. Try another.**; **That image is too large to send. Try a screenshot.**; rate limit (signed out) **You've
sent 10 today. Try again tomorrow.** The phone model is shown as sent, the hardware identifier (`iPhone16,2`).

**Tells.**
- Same container on everything — absent: the message is a field, the screenshot a row/tile, the details one list;
  the category is a segmented control on the ground, the recipient line a plain notice.
- A chip where a caption would do — absent.
- All-caps label above every section — absent; one section header ("Sent with it").
- Middle-dot metadata — deliberate in the screenshot line (format · size · what was removed) and the signed-in
  account (name · email), the app's existing metadata idiom.
- Accent on so many things — the accent is Send only; Bug's selection is the neutral segment fill (a state).
- Equal-weight stacked blocks — absent: the message field is twice the height of anything else.
- Phone-sized website — absent; the Sent state is centred, one confirmation, one button.
- More than the job above the fold — the whole compose form fits one viewport at Default; at AccessibilityL the
  message and category lead and the details follow on scroll.
- A control dressed as the primary — absent; the category pills are neutral, Remove is plain text.
- Layout only at default size — AccessibilityL captured; rows and the tile stack.

## UI first

Sample captures of the form (Default and AccessibilityL, light and dark) approved before wiring.

## Acceptance

- [ ] Approved captures in `../captures/07/`.
- [ ] Server tests: validation, size and type limits, rate limit, deletion cascade.
- [ ] Sending from the Simulator and the phone, signed in and out; the developer reads it with the script.

## Verification scope

Server unit tests; targeted app UI tests for the form; captures.

## Progress

### Form mock — 2026-10-03 (Claude)

Branch `ericlee4992/beta-07-feedback`. `Features/Settings/FeedbackSheet.swift`: the sheet (compose, sending, sent,
failure line), `FeedbackDetails` (version, build, iOS, hardware identifier, account), `FeedbackScreenshot`
(re-encode, ≤ 5 MB), and the UI-test seams (`-uiTestFeedbackSample` fills it and signs in a sample "Alex Kim";
under `-uiTestReset` a stub sender succeeds after 0.4 s, or fails with `-uiTestFeedbackFail`). Settings → Help →
Send Feedback opens it. **No networking yet.** Capture test `FloodlightFeedbackUITests` (empty signed out, filled
signed in with a screenshot, sent; light/dark × Default/AccessibilityL) on **WT-Onboarding**: **4/4 passed**
(`xcodebuild test` exit 0); 18 captures in [captures/07/](../captures/07/). First pass's Sent state was a bare
check at the top of an empty sheet — now centred with a disc; retaken.

## Comments
