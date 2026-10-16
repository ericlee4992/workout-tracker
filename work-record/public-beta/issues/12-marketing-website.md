# 12 — Marketing website (later)

Type: task
Status: needs-triage — placeholder (the user, 2026-10-15); plan it after the beta has run, before ticket 09's submission
Blocked by: 08
Related: [09 App Store launch](09-app-store-launch.md); [08](08-external-testers.md) → "Google sign-in published".
Spec: [spec.md](../spec.md).

## Why (the user, 2026-10-15)

"I would also eventually want to build a marketing website for this app." Claude suggested building it after the beta
(testers' reactions make the best copy) and before the App Store release; the user asked for it to be recorded as a
future ticket.

## Scope as discussed

- A landing page in Stacked's look (the app's colours and fonts), responsive (phone and desktop), fast.
- Copy: headline (tagline "Know your numbers. Every machine. Every gym."), features, short FAQ.
- Real app screenshots in an iPhone frame from the Simulator; optionally short screen recordings.
- Hosting on Cloudflare (the account that runs the server); the privacy and support pages can move there.
- The user reviews one or two drafts and chooses; taste is the user's call.

## To decide then

- **A domain of the user's own** (about $10–15 a year; Cloudflare sells them). It also allows Google **branding
  verification**: Google's sign-in screen does not show "Stacked" until the branding is verified, and verification needs
  a domain the user owns — `stacked-server.workers.dev` cannot be (08, 2026-10-15). The app can keep using the server's
  current address for its requests, so the domain alone needs no new build.
- If the privacy/support pages move: update the Privacy Policy URL in App Store Connect (Test Information and App
  Privacy), Google Auth Platform → Branding (home page, privacy link, authorised domain), and the links in the app if
  any; keep the old addresses redirecting.
- Email sign-up for launch news (it would collect personal data: the privacy policy and App Privacy must say so).
- The "Download on the App Store" badge and link — only once the app is public (ticket 09).

## Comments
