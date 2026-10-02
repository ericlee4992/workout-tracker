# Draft: Apple Developer Support — release bundle IDs from the Personal Team

For ticket 01, phase B. **Send only if the paid team is refused the bundle ID** ("An App ID with Identifier
'com.ericlee4992.workouttracker' is not available"). The user sends it; an agent cannot.

**Where:** developer.apple.com/contact → *Membership and Account* → *Development and Technical* (or
*Certificates, Identifiers & Profiles*) → email or a call-back. Signed in with the Apple ID that owns both
teams. Fill in the paid Team ID once Apple has approved the enrollment.

---

**Subject:** Please release bundle IDs registered by my Personal Team so my paid team can use them

Hello,

I recently enrolled in the Apple Developer Program as an individual (Team ID: **<paid team ID>**). Before that, I
developed my app with free provisioning, and Xcode registered its bundle identifiers to my Personal Team
(Team ID **X68M8SR6NA**), signed in with the same Apple ID.

When my paid team tries to register these identifiers, they are reported as not available:

- com.ericlee4992.workouttracker
- com.ericlee4992.workouttracker.widget

(If listed for the Personal Team, also: com.ericlee4992.workouttracker.watchkitapp.)

I would like to keep these bundle identifiers, because my iPhone holds months of data in the app under this
identifier and I am about to distribute it with TestFlight. Could you please delete or release these App IDs from
Personal Team X68M8SR6NA so that team <paid team ID> can register them?

The Personal Team's development profiles for these IDs expire on October 6, 2026; I can renew them while I wait if
needed. Thank you.

<your name>
<your Apple ID email>

---

After Apple confirms: retry the paid-team build (ticket 01, B2). Expect the free-team app on the phone to stop
launching once its App ID is deleted; its data stays in the container and the latest verified backup is ready
for phase D.
