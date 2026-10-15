// Ticket 08: the privacy policy (GET /privacy) and support page (GET /support), approved by the user. The policy is a
// promise about the code and the deployment: the one-year feedback expiry (feedback.ts), invocation logs off
// (wrangler.jsonc), the 30-day download and export clean-ups (scripts/feedback.mjs, README). Change those and this
// text together, and have the reviewer recheck it. Source draft: work-record/public-beta/privacy-policy-draft.md.

/** The day the policy went live (the user, 2026-10-15). Change it with the text; `npm run deploy` refuses a placeholder. */
export const POLICY_EFFECTIVE_DATE = "October 15, 2026";
export const DEVELOPER_NAME = "Eunchan Lee";
export const SUPPORT_EMAIL = "ericlee4992@gmail.com";

function page(title: string, body: string): Response {
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>${title} — Stacked</title>
<style>body{font:17px/1.5 -apple-system,system-ui,sans-serif;max-width:40rem;margin:2rem auto;padding:0 1rem;color:#0b0c0e;background:#f2f3f5}
h2{font-size:1.15rem;margin-top:2rem}a{color:#7a2ee0}
@media (prefers-color-scheme:dark){body{color:#f4f6f8;background:#060708}a{color:#b25cff}}</style></head>
<body><h1>${title}</h1>${body}</body></html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8" } });
}

const mail = `<a href="mailto:${SUPPORT_EMAIL}">${SUPPORT_EMAIL}</a>`;

export const PRIVACY_BODY = `
<p><em>Effective ${POLICY_EFFECTIVE_DATE}. Stacked is made by ${DEVELOPER_NAME} (“I”), an individual developer.
Contact: ${mail}.</em></p>

<p><strong>The short version.</strong> The workouts you log stay on your iPhone; I never receive them. An account is
optional; it holds your name, email and training profile. If you use the AI features, what you send goes through my
server to OpenAI. If you send feedback, it comes to me. TestFlight, which delivers the beta, shares some information
with me too. I don’t sell data, show ads, or track you across other companies’ apps or websites.</p>

<h2>What stays on your iPhone</h2>
<p>What you log — workouts, sets, weights, gyms, machines, templates, history, records, cardio sessions and their
routes, and your settings — is stored in the app on your iPhone. I don’t receive it, and nothing uploads it
automatically.</p>
<ul>
<li><strong>Apple Health.</strong> With your permission, Stacked reads during a workout your heart rate, active and
resting energy, and distance for walking, running, cycling or rowing where your devices record it, and shows them
during and after the workout; it saves the workouts you log to Health. Stacked does not upload Health data. It leaves
your iPhone only if you choose to send it — for example in a feedback message or screenshot, or in an export you
share.</li>
<li><strong>Location and motion.</strong> With your permission, outdoor cardio records your route, distance and pace
using location, and indoor cardio may use motion data. The route stays in the app. To draw the map behind a route,
the app asks Apple Maps for map imagery of the area around it; Apple’s handling of that request is covered by Apple’s
privacy policy, and I receive nothing from it.</li>
<li><strong>Camera and photos.</strong> You can photograph a machine or its label, or choose a photo, to identify it.
The app’s own label reader works on your iPhone, and the app does not keep the photo. AI identification sends the
photo for processing, as described below; a photo leaves your iPhone only then.</li>
<li><strong>Your exports.</strong> Settings → Export makes a file of your workout data: JSON (the fullest record,
including heart-rate series and routes) or CSV (a table of sets and cardio). You choose where it goes; that
destination may be another app or service with its own policy.</li>
</ul>
<p><strong>Deleting the app</strong> removes the data the app keeps on your iPhone. It does not remove workouts it
saved to Apple Health (manage those in the Health app), files you exported or shared, copies in your iCloud or
computer backups, or anything on my server (see <a href="#deleting">Deleting your data</a>).</p>

<h2>TestFlight (the beta)</h2>
<p>You install the beta through Apple’s TestFlight. Apple shares with me, through App Store Connect, the name and
email address you were invited with, your device and iOS version, which builds you installed, crash reports, and usage
information such as sessions, plus any feedback and screenshots you send through TestFlight. Apple’s
<a href="https://www.apple.com/legal/privacy/data/en/test-flight/">TestFlight privacy notice</a> explains this. I use
it only to run and fix the beta. If I download any of it, I delete the copy within 30 days.</p>

<h2>Your account (optional)</h2>
<p>You can use Stacked without an account. If you sign in with Apple or Google, my server keeps:</p>
<ul>
<li>your name (as Apple or Google gives it, or as you change it), your email address (if you use Apple’s “Hide My
Email”, the relay address), the sign-in method, the identifier Apple or Google gives your account for Stacked, and
when you joined;</li>
<li>for Sign in with Apple, a token Apple issues, stored encrypted and used only to revoke Stacked’s access when you
delete your account;</li>
<li>your sign-in sessions: a one-way fingerprint of each, with when it was created, last used and expires. A session
stops working after 90 days without use. Its record is removed when you sign out (if your iPhone can reach my server
at that moment), when you delete your account, or by an hourly clean-up once it has expired;</li>
<li>your <strong>training profile</strong> if you fill it in: goals, experience, days per week, minutes per session,
and optionally height and weight, as you entered them. It fills in Ask AI for Templates. You can change it at any
time; deleting your account removes it.</li>
</ul>
<p>These stay until you change them or delete your account.</p>

<h2>AI features (optional, signed in)</h2>
<p>Stacked’s AI features — identifying a machine from a photo, suggesting exercises for a machine, and building a week
of templates — run through my server on my OpenAI account. Each feature asks your permission the first time and
remembers it; you can turn each permission off in Settings → Ask AI. Nothing is sent before you allow it.</p>
<ul>
<li><strong>What is sent:</strong> for machine identification, the photo (re-encoded on your iPhone without its
location or camera details) and the app’s list of exercises; for exercise suggestions, the machine’s manufacturer and
model as you typed them, any text read from its label, and the list of exercises; for templates, your goals,
experience, schedule, optional height and weight, and the exercises and cardio available to you. The app does not
automatically include your workout history or readings from Apple Health.</li>
<li><strong>Where it goes:</strong> to my server, which passes it to OpenAI to produce the answer and returns the
answer to you. My server does not store the photo, what you sent or the answer, and does not log them. My requests ask
OpenAI not to store them for later use; OpenAI may still keep API data for up to 30 days to monitor for abuse, as
<a href="https://developers.openai.com/api/docs/guides/your-data">its policy</a> describes.</li>
<li><strong>What my server keeps:</strong> for each request, your account, which feature, the time, whether it
succeeded, how long it took and how many tokens it used — to enforce daily limits, watch costs and fix problems.
These records are kept for 90 days. Each day’s per-feature counts are kept for about two to three days. Old records
are removed by an hourly clean-up job.</li>
</ul>

<h2>Feedback (optional)</h2>
<p>If you send feedback from Settings → Send Feedback, my server keeps your message, its category, the screenshot if
you attach one (re-encoded on your iPhone without its location or camera details), and the details the form shows
before sending: the app version and build, iOS version and iPhone model, and your account if you are signed in. I read
it to fix and improve the app. Feedback sent while signed out is not attached to an account, but what you write or
show may still identify you. To limit abuse, a signed-out submission is counted under a one-way code made from your
network address and the date; the address itself is not stored in my database, and the code is removed after that day
ends (New York time).</p>
<p>Feedback and its screenshot are deleted automatically about a year after you send them, by an hourly clean-up
job (if deleting a screenshot fails, the job retries). If I download a screenshot to look at it, I delete my copy
within 30 days.</p>

<h2>Who processes data for me</h2>
<ul>
<li><strong>Cloudflare</strong> runs my server and stores its database and feedback screenshots (Cloudflare Workers,
D1 and R2). As with any web host, Cloudflare handles your network address to deliver requests and protect the service,
under its own privacy policy. My server’s logs there are kept for 3 days and hold diagnostic details — for example
which AI feature was used, whether it worked, how long it took and how many tokens it used, and the kind of any error.
I have turned off Cloudflare’s per-request logging, so they do not hold your network address, location, account or
what you sent. The database also keeps a recovery history for 7 days.</li>
<li><strong>OpenAI</strong> processes AI requests as described above.</li>
<li><strong>Apple</strong> provides Sign in with Apple, TestFlight and map imagery; <strong>Google</strong> provides
Google sign-in.</li>
</ul>
<p>I don’t sell or share data with anyone else, use it for advertising, or track you across other companies’ apps or
websites.</p>

<h2 id="deleting">Deleting your data</h2>
<ul>
<li><strong>Your account:</strong> in Settings, tap your name or email at the top, then Delete Account…. This deletes from
my live database, at once, your account, sessions, training profile, AI records, and the feedback you sent while
signed in. The feedback’s screenshots are deleted right after; if that fails, an hourly job retries until they are
gone. Any copy I downloaded is deleted within 30 days. Stacked’s Sign in with Apple access is revoked with Apple; if revocation fails, I keep the encrypted token
separately from your deleted account record, solely to retry revocation for up to 30 days, and the app tells you how
to stop Sign in with Apple yourself in iOS Settings → Apple Account → Sign in with Apple. Your workouts on your iPhone
are not touched.</li>
<li><strong>Backups:</strong> deleted data can remain for up to 7 days in the database’s recovery history, and for up
to 30 days in a copy of the database I make before risky maintenance; I delete those copies after 30 days. If I ever
have to restore the database from one of these, data deleted after it was made could reappear. I would delete again
everything I can identify as deleted since then, sign everyone out, and tell testers by email about anything I could
not identify.</li>
<li><strong>Feedback sent while signed out</strong> isn’t linked to an account; email me what you sent and roughly
when, and I will delete it, including any copy I downloaded.</li>
<li><strong>On your iPhone:</strong> delete the app (see <em>What stays on your iPhone</em> for what that does and
doesn’t remove).</li>
</ul>

<h2>Children</h2>
<p>Stacked is not directed to children under 13, and I don’t knowingly collect information from them. If you believe
a child under 13 has sent me information, email me and I will delete it.</p>

<h2>Changes and contact</h2>
<p>If this policy changes, I will update this page and its date. Questions or requests: ${mail}.</p>
`;

export const SUPPORT_BODY = `
<p>Stacked is in a beta for invited testers. Thank you for trying it.</p>

<h2>Getting help or reporting a problem</h2>
<ul>
<li><strong>In the app:</strong> Settings → Send Feedback. You can attach a screenshot; you can send it signed in or
out.</li>
<li><strong>Through TestFlight:</strong> take a screenshot while using Stacked and choose Share Beta Feedback, or
open Stacked in the TestFlight app and tap Send Beta Feedback.</li>
<li><strong>By email:</strong> ${mail}.</li>
</ul>

<h2>Your data</h2>
<ul>
<li>Your workouts are stored only on your iPhone. Settings → Export saves a copy as JSON or CSV.</li>
<li>An account is optional and needed only for the AI features. To delete your account and the data linked to it
from my server: in Settings, tap your name or email at the top, then Delete Account…. The privacy policy explains what can
remain for a while (backups, a pending Sign in with Apple revocation) and how to have feedback you sent while signed
out deleted.</li>
<li>To stop sending data to OpenAI, turn off the permissions in Settings → Ask AI.</li>
</ul>
<p>Details: the <a href="/privacy">privacy policy</a>.</p>
`;

export function privacyPage(): Response {
  return page("Privacy Policy", PRIVACY_BODY);
}

export function supportPage(): Response {
  return page("Support", SUPPORT_BODY);
}
