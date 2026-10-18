# Codex — how do other gym apps make their exercise videos/animations?

The user asked: "Is it possible to use REA on any of the gym apps that have the exercise video/motion feature, and
figure out how they did it?" — and asked that you answer the same question independently.

1. **Answer the question first** in a short section: what REA (Reverse Engineer Anything) or other tools can and
   cannot legitimately establish here, given that iOS App Store binaries are FairPlay-encrypted and licensed under
   terms that forbid reverse engineering, that we will not sign in or create accounts, and that we will not download
   APKs from third-party mirrors. (Claude's view: passive study of public web exercise pages — network requests,
   media hosts, file naming, `<video>` attributes, credits/terms pages — is fine and can reveal sourcing; decompiling
   apps is not.) Agree or disagree with reasons. If you have REA tools in your session, say so and use them; if not,
   use your web browsing and plain HTTP reads of public pages.
2. **Study these apps' public web exercise pages** (Claude is covering Hevy, Fitbod, JEFIT and StrengthLog in
   parallel — do not duplicate): **MuscleWiki, Strong, Boostcamp, Alpha Progression, Gymshark Training, Jefit-like
   others you find, Caliber, Fitness AI, Liftosaur, Ladder** — any that publish exercise media on the open web. For
   each: is there a public exercise page; what media (video / GIF / 3D / photo / illustration); where it is served from
   (host, folder and file naming that hints at a vendor, e.g. Lyfta's `GymvisualMP4/…`); credits, licence or
   "© vendor" notices; any public statement (blog, press, job post, help centre) about how they produce media (filmed
   in-house with trainers, 3D studio, licensed vendor). Read-only; do not download media files beyond what a page
   loads to display; no sign-in.
3. **Patterns**: what are the industry's common production routes (filmed trainers, licensed 3D vendors such as
   Gym visual or others you find, in-house 3D, AI), and what does each imply for Stacked (cost, consistency, machines).
   Name any **other licensable vendors** besides Gym visual that you discover, with their licence terms if public.

Write `work-record/exercise-media/research/codex-competitor-study.md` with sources linked and facts vs. inferences
marked. Do not modify other files; do not commit or push. End the file with a line `Done.`
