# Ticket 08 — App Store Connect entries (for the user to paste)

Prepared 2026-10-15 by Claude from the live policy (server `8e0434be`, `main` `1ce3424`) and the draft App Privacy table
(privacy-policy-draft.md, Codex-reviewed). Every value here is a proposal until the user saves it in App Store Connect.

## 1. TestFlight → Test Information (external testing)

| Field | Value |
|---|---|
| Beta App Description | see below |
| Feedback Email | ericlee4992@gmail.com |
| Marketing URL | (leave empty) |
| Privacy Policy URL | https://stacked-server.stacked-server.workers.dev/privacy |

**Beta App Description:**

> Stacked — know your numbers. Every machine. Every gym.
>
> A workout logger that knows your gym's machines. Log sets fast, see your bests per machine and per gym, and track
> cardio with Apple Health. Your workouts stay on your iPhone. Optional sign-in (Apple or Google) unlocks AI help:
> identify a machine from a photo, suggest exercises for a machine, or build a week of templates.

## 2. Beta App Review Information

| Field | Value |
|---|---|
| Contact first / last name | Eunchan / Lee |
| Phone | **the user's number (not in the repository)** |
| Email | ericlee4992@gmail.com |
| Sign-in required | **No** — leave the demo account empty |

**Review notes:**

> Stacked works fully without an account: logging workouts, gyms, machines, templates, cardio and Apple Health all run
> on the device. An account is optional and only needed for the AI features (Scan Machine, Suggest exercises with AI,
> Ask AI for Templates). Please use Sign in with Apple with any Apple ID; Google sign-in is limited to registered test
> users during the beta. AI requests go through the developer's server to OpenAI after the user grants per-feature
> permission, with daily limits per account. Account deletion: Settings → the name at the top → Delete Account….

## 3. What to Test (build 5)

> First external build. Please try: logging a workout with a few sets; adding your gym and a machine (Scan Machine
> works best signed in); a cardio session; Ask AI for Templates; and on a machine with a new model, "Suggest exercises
> with AI". Send anything odd from Settings → Send Feedback (a screenshot helps).

## 4. App Privacy (App Store Connect → App Privacy)

Not used for tracking (no data used for tracking; no third-party advertising/data brokers). Data types to declare —
all **linked to the user**, **not used for tracking**:

| Data type | Purposes | Why |
|---|---|---|
| Contact Info → Name | App Functionality | account display name |
| Contact Info → Email Address | App Functionality | Apple/Google email or relay |
| Identifiers → User ID | App Functionality | account ID, provider identifier |
| Health & Fitness → Health | App Functionality, Product Personalization | optional height and weight in the training profile and template requests |
| Health & Fitness → Fitness | App Functionality, Product Personalization | goals, experience, schedule |
| User Content → Photos or Videos | App Functionality | photos sent for AI identification; feedback screenshots |
| User Content → Customer Support | App Functionality | feedback messages (signed-in feedback is linked) |
| User Content → Other User Content | App Functionality, Product Personalization | text sent to AI: goals, manufacturer/model, label text |
| Usage Data → Product Interaction | App Functionality | AI requests per feature per day (limits) |
| Diagnostics → Performance Data | App Functionality | AI request latency and outcome |
| Diagnostics → Other Diagnostic Data | App Functionality | app/iOS version and iPhone model with feedback; token counts |

**Not declared:** HealthKit readings (stay on the device), Location (routes stay in the app; map imagery requests are
Apple's), crash data (the app sends none; TestFlight's crash reports are collected by Apple), Analytics (the AI
counts serve limits and cost control, not product analytics). **Decided by Claude, for the user's confirmation:** the
signed-out feedback limiter's one-way, keyed code of the network address and date (deleted when the New York day ends,
never stored as an address, used only against abuse) is not declared as a separate type — say if you would rather
declare it (Identifiers → Device ID is the nearest category, and would overstate it). Cloudflare's per-request logs,
which held IP and location, are off (D61).
