# Stacked — privacy policy and App Privacy answers (DRAFT for the user's review)

Ticket 08 prep, written 2026-10-03 by Claude from the code and server on `main` `7c70d14` (tickets 02, 03 server half,
05 mock + server side, 06 server half, 07 merged). **Not published.** Every sentence is the user's to approve; the reviewer (Codex)
checks it against the code and the server before it goes live at the Worker's `/privacy`. Placeholders are in
**[brackets]**. Statements that depend on work not built yet are marked *(after ticket NN)* — publish the policy only
when they are true, or remove them.

---

## Privacy Policy — Stacked

*Effective [date]. Stacked is made by [developer's legal name] ("I"), an individual developer.*

**The short version.** Your workouts stay on your iPhone. An account is optional; it holds your name, email and
training profile. If you use the AI features or send feedback, what you send goes to my server, and AI requests go on
to OpenAI. I don't sell data, show ads, or track you across apps.

### What stays on your iPhone

Everything you log — workouts, sets, weights, gyms, machines, templates, history, records, cardio sessions and their
routes, heart rate shown during a workout, and your settings — is stored only on your iPhone. I never receive it. It is
deleted when you delete the app. You can export it yourself (Settings → Export) as a file you control.

- **Apple Health.** With your permission, Stacked reads your heart rate during a workout and saves the workouts you log
  to Health. Health data is read and written on your device and is never sent to my server or to OpenAI.
- **Location and motion.** With your permission, outdoor cardio records your route, distance and pace with location,
  and indoor cardio may use motion data. These stay on your iPhone.
- **Camera and photos.** You can photograph a machine or its label, or choose a photo, to identify it. The photo is
  not saved by the app. It is sent anywhere only if you use AI identification (below).

### Your account (optional)

You can use Stacked without an account. If you sign in with Apple *(after ticket 03)* or Google *(after ticket 04)*,
my server keeps:

- your name (as Apple or Google gives it, or as you change it), your email address (if you use Apple's "Hide My
  Email", the relay address), the sign-in method, a provider account identifier, and when you joined;
- for Sign in with Apple, a token Apple issues, stored encrypted and used only to revoke Stacked's access when you
  delete your account;
- a sign-in session (only a fingerprint of it is stored), which expires after 90 days without use;
- your **training profile** if you fill it in *(after ticket 05)*: goals, experience, days per week, minutes per
  session, and optionally height and weight, as you entered them. It fills in Ask AI for Templates.

### AI features (optional, signed in) *(after ticket 06's app switch)*

Stacked's AI features — identifying a machine from a photo, suggesting exercises for a machine, and building a week of
templates — run through my server on my OpenAI account. Each asks your permission before anything is sent, and you
can turn each permission off in Settings.

- **What is sent:** for machine identification, the photo (re-encoded without its location or camera details) and the
  app's list of exercises; for exercise suggestions, the text read from a machine's label and the list of exercises;
  for templates, your goals, experience, schedule, optional height and weight, and the exercises and cardio available
  to you.
- **Where it goes:** to my server, which passes it to OpenAI to produce the answer, and returns the answer to you.
  My server does not store the photo, what you sent or the answer. OpenAI is asked not to store the request
  (`store: false`); OpenAI's own data-retention policy still applies to API requests
  ([OpenAI's API data usage](https://openai.com/policies/api-data-usage-policies)).
- **What my server keeps:** for each request, your account, which feature, the time, whether it succeeded, how long it
  took and how many tokens it used — to enforce daily limits and watch costs. These records are deleted after 90 days.
  Daily counts are kept for two days.

### Feedback (optional)

If you send feedback from Settings → Send Feedback, my server keeps your message, its category, the screenshot if you
attach one (re-encoded without its location or camera details), and the details the form shows you before sending:
the app version and build, iOS version and iPhone model, and your account if you are signed in. Only I read it.
If you are not signed in, a daily limit uses a one-way, day-specific code derived from your network address; the
address itself is not stored, and the code is deleted the next day. Feedback is kept until I delete it or you ask me to [retention to decide].
TestFlight's own feedback (screenshots you send through TestFlight) goes to Apple and to me through App Store Connect.

### Who processes data for me

- **Cloudflare** runs my server and stores its database and feedback screenshots (Cloudflare Workers, D1 and R2).
  Cloudflare keeps operational logs of requests to my server for 7 days (Workers Logs: each request's time, method,
  path, status and related metadata, and the counts my server logs — never what you sent) [confirm the exact fields
  in the dashboard after the first deploy].
- **OpenAI** processes AI requests as described above.
- **Apple** provides Sign in with Apple and TestFlight; **Google** provides Google sign-in *(after ticket 04)*.

I don't sell or share data with anyone else, use it for advertising, or track you across other companies' apps or
websites.

### Deleting your data

- **Account:** Profile → Delete Account deletes your account, sessions, training profile, AI usage records and the
  feedback you sent while signed in (with its screenshots) from my server, and revokes Stacked's Sign in with Apple
  access. Your workouts on your iPhone are not touched. *(after ticket 03's app half)*
- **Feedback sent while signed out** cannot be linked to you; email me with what you sent and roughly when, and I will
  delete it.
- **Everything on your iPhone:** delete the app.

### Children

Stacked is not directed to children under 13 [confirm the age the user wants to state].

### Changes and contact

If this policy changes, I will update this page and its date. Questions or requests: **[support email]**.

---

## App Store Connect — App Privacy answers (draft)

"Data linked to you" = tied to the account; nothing is used for tracking. Confirm each against the build that ships
to external testers (ticket 08).

| Category (Apple's term) | Collected? | What | Linked | Purpose (Apple's terms) |
|---|---|---|---|---|
| Contact Info → Name | Yes, if signed in | display name | Yes | App Functionality |
| Contact Info → Email Address | Yes, if signed in | Apple/Google email or relay | Yes | App Functionality |
| Identifiers → User ID | Yes, if signed in | account ID, provider subject | Yes | App Functionality |
| Health & Fitness → Fitness | Yes, if a training profile is saved or AI templates used | goals, experience, schedule, height, weight | Yes | App Functionality |
| Health & Fitness → Health | **No** | HealthKit stays on the device | — | — |
| User Content → Photos or Videos | Yes, for AI identification and feedback screenshots | sent for processing; screenshots stored | Yes when signed in | App Functionality (AI); Developer's Communications? → [decide: feedback is likely "Customer Support"/"Other"] |
| User Content → Customer Support | Yes | feedback messages | Yes if signed in | App Functionality / Customer Support |
| User Content → Other User Content | Yes | text sent to AI (plate text, goals) | Yes | App Functionality |
| Usage Data → Product Interaction | Yes | AI request counts per feature | Yes | App Functionality (limits); Analytics? → [decide] |
| Diagnostics → Other Diagnostic Data | Yes, with feedback | app version, iOS version, iPhone model | Yes if signed in | App Functionality / Customer Support |
| Location | **No** (routes stay on the device) | — | — | — |
| Tracking | **No** | — | — | — |

**Notes for the review.**
- Apple counts data "collected" when it leaves the device to the developer or a third party, even briefly — so photos
  and text sent through the server to OpenAI count as collected even though the server does not store them.
- Signed-out feedback is "not linked" (no account) but a screenshot or message could still identify someone if they
  write their name; the policy says so implicitly ("only I read it").

## Open items before publishing

1. The user's legal name as it will appear, a support email, and the effective date.
2. Feedback retention period (none is enforced by the server today) and the children/age statement.
3. Cloudflare Workers Logs (`observability.enabled` in `wrangler.jsonc`): the free plan keeps them **7 days**
   ([Cloudflare: Workers Logs](https://developers.cloudflare.com/workers/observability/logs/workers-logs/)); each request
   produces an "invocation log" with request/response metadata. After the first deploy, check one in the dashboard
   (does it hold the client IP or headers?) and either describe it or turn invocation logs off in `wrangler.jsonc`.
4. The camera/photo permission strings in the app still say photos go "to OpenAI"; with ticket 06's app switch they
   should name the developer's server too (D56 disclosure update).
5. Publish only what is true at the time: sections marked *(after ticket NN)* wait for those tickets.
6. Codex checks every statement against the code and the server (ticket 08's review); the user approves the wording.
