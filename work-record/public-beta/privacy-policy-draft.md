# Stacked — privacy policy and App Privacy answers (DRAFT for the user's review)

Ticket 08 prep, written 2026-10-03 by Claude from the code and server on `main` `7c70d14`; revised the same day after
Codex review 08 (17 findings, all taken — see the ticket). **Not published.** Every sentence is the user's to approve;
the reviewer checks it against the code and the server again before it goes live at the Worker's `/privacy`.
Placeholders are in **[brackets]**.

**What this text describes.** The build external testers will get (ticket 08): sign-in (03/04), the profile and
training profile (05), AI through the server (06's app switch) and in-app feedback (07) all wired, and the server
deployed. **It is not true of today's app**, where nothing reaches the server and AI goes from the phone straight to
OpenAI on a device key (`TerraAccess.client`, `TerraClient`). Publish it only when the release gates at the end hold.

---

## Privacy Policy — Stacked

*Effective [date]. Stacked is made by [developer's legal name] ("I"), an individual developer. Contact:
[support email].*

**The short version.** The workouts you log stay on your iPhone; I never receive them. An account is optional; it holds
your name, email and training profile. If you use the AI features, what you send goes through my server to OpenAI. If
you send feedback, it comes to me. TestFlight, which delivers the beta, shares some information with me too. I don't
sell data, show ads, or track you across other companies' apps or websites.

### What stays on your iPhone

What you log — workouts, sets, weights, gyms, machines, templates, history, records, cardio sessions and their routes,
and your settings — is stored in the app on your iPhone. I don't receive it, and nothing uploads it automatically.

- **Apple Health.** With your permission, Stacked reads during a workout your heart rate, active and resting energy,
  and distance for walking, running, cycling or rowing where your devices record it, and shows them during and after
  the workout; it saves the workouts you log to Health. Stacked does not upload Health data. It leaves your iPhone
  only if you choose to send it — for example in a feedback message or screenshot, or in an export you share.
- **Location and motion.** With your permission, outdoor cardio records your route, distance and pace using location,
  and indoor cardio may use motion data. The route stays in the app. To draw the map behind a route, the app asks
  Apple Maps for map imagery of the area around it; Apple's handling of that request is covered by Apple's privacy
  policy, and I receive nothing from it.
- **Camera and photos.** You can photograph a machine or its label, or choose a photo, to identify it. Reading the
  label happens on your iPhone; the app does not keep the photo. A photo is sent anywhere only if you use AI
  identification (below).
- **Your exports.** Settings → Export makes a file of your workout data: JSON (the fullest record, including heart-rate
  series and routes) or CSV (a table of sets and cardio). You choose where it goes; that destination may be another
  app or service with its own policy.

**Deleting the app** removes the data the app keeps on your iPhone. It does not remove workouts it saved to Apple
Health (manage those in the Health app), files you exported or shared, copies in your iCloud or computer backups, or
anything on my server (see *Deleting your data*).

### TestFlight (the beta)

You install the beta through Apple's TestFlight. Apple shares with me, through App Store Connect, the name and email
address you were invited with, your device and iOS version, which builds you installed, crash reports, and usage
information such as sessions, plus any feedback and screenshots you send through TestFlight. Apple's TestFlight
privacy notice explains this ([Apple: TestFlight & privacy](https://www.apple.com/legal/privacy/data/en/test-flight/)).
I use it only to run and fix the beta. [State how long you keep TestFlight feedback you export, if you export any.]

### Your account (optional)

You can use Stacked without an account. If you sign in with Apple or Google, my server keeps:

- your name (as Apple or Google gives it, or as you change it), your email address (if you use Apple's "Hide My
  Email", the relay address), the sign-in method, the identifier Apple or Google gives your account for Stacked, and
  when you joined;
- for Sign in with Apple, a token Apple issues, stored encrypted and used only to revoke Stacked's access when you
  delete your account;
- your sign-in sessions: a one-way fingerprint of each, with when it was created, last used and expires. A session
  stops working after 90 days without use; its record is removed when you sign out, delete your account, or next
  present an expired session;
- your **training profile** if you fill it in: goals, experience, days per week, minutes per session, and optionally
  height and weight, as you entered them. It fills in Ask AI for Templates, and you can change or clear it.

These stay until you change them or delete your account.

### AI features (optional, signed in)

Stacked's AI features — identifying a machine from a photo, suggesting exercises for a machine, and building a week of
templates — run through my server on my OpenAI account. Each feature asks your permission the first time and
remembers it; you can turn each permission off in Settings → Ask AI. Nothing is sent before you allow it.

- **What is sent:** for machine identification, the photo (re-encoded on your iPhone without its location or camera
  details) and the app's list of exercises; for exercise suggestions, the machine's manufacturer and model as you
  typed them, any text read from its label, and the list of exercises; for templates, your goals, experience,
  schedule, optional height and weight, and the exercises and cardio available to you. Your workout history and
  Health data are not sent.
- **Where it goes:** to my server, which passes it to OpenAI to produce the answer and returns the answer to you. My
  server does not store the photo, what you sent or the answer, and does not log them. My requests ask OpenAI not to
  store them for later use (`store: false`); OpenAI may still keep API data for up to 30 days to monitor for abuse,
  as its policy describes ([OpenAI: your data](https://developers.openai.com/api/docs/guides/your-data)).
- **What my server keeps:** for each request, your account, which feature, the time, whether it succeeded, how long it
  took and how many tokens it used — to enforce daily limits, watch costs and fix problems. These records are kept
  for 90 days. Each day's per-feature counts are kept for about two to three days. Old records are removed by an
  hourly clean-up job.

### Feedback (optional)

If you send feedback from Settings → Send Feedback, my server keeps your message, its category, the screenshot if you
attach one (re-encoded on your iPhone without its location or camera details), and the details the form shows before
sending: the app version and build, iOS version and iPhone model, and your account if you are signed in. I read it
to fix and improve the app. Feedback sent while signed out is not attached to an account, but what you write or show
may still identify you. To limit abuse, a signed-out submission is counted under a one-way code made from your network
address and the date; the address itself is not stored in my database, and the code is removed after that day ends
(New York time). Feedback is kept [retention to decide — none is enforced today]. I may download a screenshot to look
at it; [say how long such copies are kept].

### Who processes data for me

- **Cloudflare** runs my server and stores its database and feedback screenshots (Cloudflare Workers, D1 and R2).
  Cloudflare keeps operational logs of requests to my server — [3 days on the Free plan / 7 on Paid; confirm the plan]
  — with request and response metadata, and the counts-only lines my server writes; [describe the exact fields after
  checking a deployed log, or state that request logging is turned off]. Its database also keeps a recovery history
  for [7 days on Free / 30 on Paid] (D1 Time Travel).
- **OpenAI** processes AI requests as described above.
- **Apple** provides Sign in with Apple, TestFlight and map imagery; **Google** provides Google sign-in.

I don't sell or share data with anyone else, use it for advertising, or track you across other companies' apps or
websites.

### Deleting your data

- **Your account:** Profile → Delete Account deletes from my live database, at once, your account, sessions, training
  profile, AI records, and the feedback you sent while signed in. The feedback's screenshots are deleted right after;
  if that fails, an hourly job retries until they are gone. Stacked's Sign in with Apple access is revoked with Apple;
  if Apple can't be reached, the encrypted token is kept, no longer linked to you, and retried for up to 30 days, and
  the app tells you how to stop Sign in with Apple yourself in iOS Settings → Apple Account → Sign in with Apple. Your
  workouts on your iPhone are not touched. The database's recovery history (above) still holds deleted rows until it
  expires [and a restore from it or from a backup re-applies deletions made since — describe the procedure].
- **Feedback sent while signed out** isn't linked to an account; email me what you sent and roughly when, and I will
  delete it, including any copy I downloaded.
- **On your iPhone:** delete the app (see *What stays on your iPhone* for what that does and doesn't remove).

### Children

[The age statement the user chooses, e.g. "Stacked is not directed to children under 13."]

### Changes and contact

If this policy changes, I will update this page and its date. Questions or requests: **[support email]**.

---

## App Store Connect — App Privacy answers (draft)

**Apple's definitions** ([Apple: App privacy details](https://developer.apple.com/app-store/app-privacy-details/)):
data is *collected* when it is transmitted off the device in a way that the developer or its partners can access it
for longer than needed to service the request in real time. Data is *linked* when it is tied to the user's identity —
an account, a device, or other details that identify them. *Tracking* is linking with other companies' data for
advertising or sharing with data brokers. Data that Apple's frameworks collect for Apple (Apple Maps imagery) is
Apple's to disclose, not the app's.

For the external-test build described above. Nothing is used for tracking.

| Category → type | Collected | What | Linked | Purposes |
|---|---|---|---|---|
| Contact Info → Name | Yes (signed in) | display name | Yes | App Functionality |
| Contact Info → Email Address | Yes (signed in) | Apple/Google email or relay | Yes | App Functionality |
| Identifiers → User ID | Yes (signed in) | account ID, provider identifier | Yes | App Functionality |
| Health & Fitness → Health | Yes (if given) | height and body weight in the training profile and template requests | Yes | App Functionality, Product Personalization |
| Health & Fitness → Fitness | Yes (if given) | goals, experience, schedule | Yes | App Functionality, Product Personalization |
| User Content → Photos or Videos | Yes | photos sent for AI identification (passed to OpenAI); feedback screenshots (kept) | Yes | App Functionality |
| User Content → Customer Support | Yes | feedback messages | Yes [signed out: still potentially identifying — decide; Apple asks about linkage in practice] | App Functionality |
| User Content → Other User Content | Yes | text sent to AI: goals, manufacturer/model, label text | Yes | App Functionality, Product Personalization |
| Usage Data → Product Interaction | Yes | AI requests per feature per day | Yes | App Functionality [+ Analytics only if the counts are used to study usage — decide] |
| Diagnostics → Performance Data | Yes | AI request latency and outcome | Yes | App Functionality |
| Diagnostics → Other Diagnostic Data | Yes | app version, iOS version, iPhone model with feedback; token counts | Yes | App Functionality |
| Health → HealthKit readings | No | read and written on the device only | — | — |
| Location | No | routes stay in the app (Apple Maps imagery requests are Apple's) | — | — |
| Tracking | No | — | — | — |

Open for the answers: whether the daily network-address code (anti-abuse, removed after the day) and Cloudflare's
request logs are disclosed as Identifiers/Diagnostics once the deployed log fields are known; how TestFlight's
crash and usage data are treated (Apple collects them for the developer; confirm against Apple's current guidance
when answering).

---

## Release gates before publishing

1. **The user's details:** legal name, support email, effective date, age statement, feedback retention (and implement
   any automatic retention the policy promises — none exists today), and retention for downloaded screenshots and
   exported TestFlight feedback.
2. **The build:** tickets 03 (and 04 if Google ships), 05 and 06's app switch wired; the legacy OpenAI device key and its
   Keychain path removed (06); all three AI consent disclosures — the photo step (`ScanSteps.swift`), the routine step
   (`AIEquipmentStep.swift`), the model-suggestion alert (`ModelPicker.swift`) and Settings → Ask AI
   (`AskAISettingsSheet.swift`) — and the camera/photo usage strings name the developer's server and OpenAI; decide
   whether the new recipient needs fresh consent (bump the v1 consent flags in `TerraAccess`) and record it in
   DECISIONS. The Health usage string should name the energy and distance reads.
3. **The server, deployed:** check a Workers Logs invocation record (does it hold the client IP or headers?) and either
   describe it here or turn invocation logs off; confirm the Cloudflare plan's log retention and D1 Time Travel
   window; write the D1 export/backup procedure (ticket 08) so a restore re-applies deletions; check that the hourly
   job runs (prune, sweep, revocation retries).
4. **The pages:** replace `server/src/pages.ts`'s placeholders with the approved policy and a support page.
5. **Review:** Codex rechecks every statement against the release build and the deployed server; the user approves
   the wording.
