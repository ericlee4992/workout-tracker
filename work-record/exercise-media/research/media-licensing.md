# Exercise form media: licensing research for Stacked

Researched 2026-10-18 against primary sources (official sites, API responses, licence files, terms pages,
GitHub repos). Not legal advice.

How to read this report:
- **[F]** marks a fact, with its source URL. Quotes are verbatim.
- **[I]** marks my inference or opinion.
- "We" means the Stacked iOS app, its public GitHub repo and its Cloudflare Worker / R2 backend.

Contents:
1. wger
2. ExerciseDB V1 (AscendAPI's free/open-source tier)
3. ExerciseDB V2 (AscendAPI's paid API on RapidAPI), plus the other "ExerciseDB" (exercisedb.io / Justin's RapidAPI listing)
4. Gym visual (the probable upstream of the ExerciseDB media)
5. YouTube embeds in an iOS app
6. Muscle maps
7. Other clearly licensed sources
8. Comparison table

---

## 1. wger (wger.de)

### Summary
wger is an AGPL open-source workout manager with a free, keyless, read-only REST API. Exercise text and
media come from contributors under Creative Commons licences, and **every record carries its own licence
and author fields**. In practice almost everything is CC BY-SA 4.0, with a minority of images under CC BY-SA
3.0. Commercial use, bundling, caching and re-hosting on R2 are all allowed by those licences, as long as
we credit each item (title / author / source / licence) and release our own *edits or translations* of
wger text or media under CC BY-SA. Showing wger content does not put our app's code under BY-SA. Media
coverage is thin. About 30% of exercises have at least one image (mostly stills, 5 animated GIFs), and only
46 of 932 exercises have a video. All 78 videos come from one contributor and are large 1080p HEVC `.MOV` files.

### Facts with citations
**Licensing model**
- [F] Repo README: "Application Code: AGPL-3.0-or-later" and "Exercise/Ingredient Data: Creative Commons (see individual entries)". https://github.com/wger-project/wger
- [F] The licence table the API serves has five licences: CC-BY-SA 3 (id 1), CC-BY-SA 4 (id 2), CC0 (id 3), CC-BY 4 (id 4) and ODbL (id 5). https://wger.de/api/v2/license/
- [F] Every licensed model inherits `AbstractLicenseModel`. Its docstring says "Implements TASL (Title - Author - Source - License) for proper attribution". The fields are `license` (FK, **default CC-BY-SA 4**), `license_title`, `license_object_url`, `license_author`, `license_author_url` and `license_derivative_source_url`. Its attribution renderer outputs "`{title} by {author} is licensed under {license}{ / A derivative work from the original work}`". https://github.com/wger-project/wger/blob/master/wger/utils/models.py

**Licence fields exposed per endpoint** (read-only GETs on 2026-10-18)

| Endpoint | Licence fields present |
|---|---|
| `/api/v2/exerciseinfo/` (exercise) | `license` (object: `full_name`, `short_name`, `url`), `license_author`, `author_history`, `total_authors_history` |
| `/api/v2/exerciseinfo/` → `translations[]` (name/description) | `license` (id), `license_title`, `license_object_url`, `license_author`, `license_author_url`, `license_derivative_source_url`, `author_history` |
| `/api/v2/exercise/` | only `license_author` (no `license` field) |
| `/api/v2/exercise-translation/` | only `license_author` |
| `/api/v2/exerciseimage/` | `license` (id), `license_title`, `license_object_url`, `license_author`, `license_author_url`, `license_derivative_source_url`, `author_history`, plus `is_ai_generated`, `style` |
| `/api/v2/video/` | same six licence fields + `author_history` |
| `/api/v2/muscle/` | **no licence fields** (see section 6) |

- [F] Sample `exerciseinfo` record (id 9, "2 Handed Kettlebell Swing"): `"license":{"id":2,...,"short_name":"CC-BY-SA 4"}`, `"license_author":"deusinvictus"`. https://wger.de/api/v2/exerciseinfo/?limit=1
- [F] In a sample of 100 exercises (offset 400), all 100 were CC-BY-SA 4 at exercise level, and all 332 of their translations were licence id 2 (CC-BY-SA 4). https://wger.de/api/v2/exerciseinfo/?limit=100&offset=400
- [F] Images (all 383): 295 are CC-BY-SA 4 and 88 are CC-BY-SA 3. 104 of the 383 have an **empty `license_author`**. The top credited authors are Everkinetic (83), Franpol (30) and Davidgj32 (23). 46 are flagged `is_ai_generated: true`. https://wger.de/api/v2/exerciseimage/?limit=500
- [F] Videos (all 78): all are CC-BY-SA 4 and all are by `license_author` "Goulart". https://wger.de/api/v2/video/?limit=100

**Counts and formats** (2026-10-18)
- [F] 932 exercises (`count` at https://wger.de/api/v2/exerciseinfo/?limit=1) and 3,514 translations (https://wger.de/api/v2/exercise-translation/?limit=1).
- [F] 383 images spread over **279 distinct exercises**. File types: png 260, jpg 68, webp 38, jpeg 8, **gif 5**, jfif 3, avif 1. Small and medium thumbnails come pre-generated (`.200x200_q85`, `.400x400_q85`).
- [F] All 5 GIFs are **animated**: by GIF frame-control blocks they have about 12, 103, 30, 12 and 12 frames, and they are 0.2 to 1.6 MB. They belong to exercises 1225, 1227, 1519, 1593 and 203. The remaining images are stills.
- [F] The image `style` choices are 1=Line, 2=3D, 3=Low-poly, 4=Photo, 5=Other, with **default = Photo**. https://github.com/wger-project/wger/blob/master/wger/exercises/models/image.py
- [F] 78 videos over **46 distinct exercises**. Containers: 75 `.MOV`, 3 `.MP4`. Codecs: 54 HEVC, 24 H.264. All 1920×1080. Median size 30 MB; 3.57 GB in total.

**API terms, throttling, bulk use**
- [F] API docs: "Public endpoints, such as the list of exercises or the ingredients, can be accessed without authentication." Throttles apply only to login, registration and ingredient endpoints: "All other endpoints are unthrottled." Very large `?limit=` pages "may put load on the server". https://wger.readthedocs.io/en/latest/api/api.html
- [F] Source settings: `'exercise_create': '20/hour'` throttles **POSTs only** ("reads and edits are not"). https://github.com/wger-project/wger/blob/master/settings/settings_global.py
- [F] wger ships management commands `sync-exercises`, `download-exercise-images` and `download-exercise-videos`. Their help text reads: "Download exercise images from wger.de and update the local database". https://github.com/wger-project/wger/tree/master/wger/exercises/management/commands
- [F] The ToS template in the repo is a placeholder ("Add your terms of service here"). https://github.com/wger-project/wger/blob/master/wger/software/templates/tos.html
- [F] wger.de's HTML pages, including https://wger.de/en/software/terms-of-service, sit behind an Anubis anti-scraping proof-of-work page, so I could not read the deployed ToS text. The JSON API answered normal requests.
- [F] The API page template asks: "If you plan to use it to generate a client or similar drop us a line first!" https://github.com/wger-project/wger/blob/master/wger/software/templates/api.html

**CC BY-SA 4.0 obligations** (legal code: https://creativecommons.org/licenses/by-sa/4.0/legalcode.en)
- [F] §3(a)(1): when you share, you must retain the creator identification, copyright notice, licence notice, disclaimer notice and "a URI or hyperlink to the Licensed Material to the extent reasonably practicable". You must also "indicate if You modified the Licensed Material", and indicate the licence with its text or URI. §3(a)(2): this may be done "in any reasonable manner based on the medium, means, and context".
- [F] §3(b) (ShareAlike) applies only "if You Share Adapted Material You produce". The Adapter's License must be BY-SA 4.0 or later, or a compatible licence, and you may not add terms or ETMs that restrict the Adapter's License.
- [F] §1(a) defines Adapted Material as material "derived from or based upon the Licensed Material and in which the Licensed Material is translated, altered, arranged, transformed, or otherwise modified".
- [F] §4 (sui generis database rights): if you put "all or a substantial portion of the database contents" into a database in which you have such rights, that database "(but not its individual contents) is Adapted Material".
- [F] §2(a)(5)(C): "You may not offer or impose any additional or different terms or conditions on, or apply any Effective Technological Measures to, the Licensed Material if doing so restricts exercise of the Licensed Rights by any recipient".
- [F] CC FAQ on collections: "You may choose a license for the collection, however this does not change the license applicable to the original material." It also says "translating a work from one language to another … [is] generally considered [an adaptation]". https://creativecommons.org/faq/
- [F] CC FAQ on DRM: "When you receive material under a Creative Commons license, you may not place additional terms and conditions … This includes using effective technological measures (ETMs) that would restrict a licensee's ability to exercise …" https://creativecommons.org/faq/#can-i-use-effective-technological-measures-such-as-drm-when-i-share-cc-licensed-material

### What it allows for us
- [F/I] **Commercial use is allowed.** No wger licence (BY-SA 3/4, BY 4, CC0, ODbL) has a non-commercial clause. A paid or subscription app is fine.
- [I] **Bundling, caching and re-hosting on R2 is allowed** by the licences, which grant reproduction and sharing. Nothing I could read in the API docs or source forbids bulk download, and wger ships its own sync and download tooling for this purpose. Courtesy: do a one-off sync with modest page sizes instead of hitting wger.de live from every phone, then serve from R2. Transcoding the HEVC `.MOV` files to smaller H.264/HEVC MP4 counts as a "technical modification" (§2(a)(4)), not an adaptation.
- [I] **Share-alike does not reach our Swift code.** Displaying unmodified wger images or text next to our own code and UI makes a collection, not an adaptation. CC's FAQ confirms the original keeps its own licence inside a collection.
- [I] Share-alike **does** reach these:
  - Our edited or translated wger descriptions, and any cropped, recoloured or retouched wger images. Each must be released under CC BY-SA 4.0, marked as modified, and the original credit kept.
  - In jurisdictions with database rights (EU/UK), our compiled exercise database **as a database**, if it contains a substantial part of wger. This is §4. Our own original text added alongside is not forced to BY-SA unless it modifies wger text.
- [I] Easy compliance path:
  - An in-app "Credits" or "Licences" screen, plus a per-exercise "ⓘ" or caption line generated from the TASL fields: "{name} by {license_author} ({license_short_name}), from wger.de, {license_url}".
  - A `CREDITS`/`LICENSES` file in the public repo.
  - Put any adapted wger content in the public repo (or a public R2 JSON) under CC BY-SA 4.0. That also covers the DRM concern below.

### Blockers / risks
- [F] **Coverage is the main limitation.** Images exist for 279 of 932 exercises (~30%). Only 5 images are animated. Videos exist for 46 exercises (~5%), all by a single contributor.
- [F] **Attribution data is incomplete.** 104 images have a blank `license_author`. [I] For those, credit "wger.de contributors" and link the image's wger page or URL. Consider excluding them if they are not clearly licensed.
- [F] **Licence quality varies.** 46 images are AI-generated. [I] Contributors self-certify their licences and there is no upstream provenance check, so a small risk of mislabelled uploads exists, as with any wiki-style source. Keep the ability to remove an item quickly.
- [I] **App Store DRM vs. §2(a)(5)(C).** FairPlay is arguably an Effective Technological Measure. The common mitigation, and the reading I'd rely on, is that recipients' rights are not restricted when the same material stays freely available without DRM: on wger.de, in our public repo, or in a public R2 JSON. Low risk, but it is a reason to publish our adapted data openly.
- [F] The video files are heavy (median 30 MB) and mostly HEVC `.MOV`. They need transcoding before use.
- [F] I could not read wger.de's deployed ToS (Anubis); the source template is empty.

### Open questions
- What does wger.de's deployed ToS page say? It needs reading in a normal browser. Also, should we email the wger maintainers about periodic syncs? The API page invites contact before building a client.
- Are any exercise-level licences other than CC-BY-SA 4? I sampled 100 of 932. A full sync can tally this cheaply.
- How should credits appear inside the in-workout pop-up? [I] A short credit line plus a tap-through to the full TASL credit should count as "reasonable manner" under §3(a)(2).

---

## 2. ExerciseDB V1 (AscendAPI "Free Version", formerly ExerciseDB)

### Summary
ExerciseDB has rebranded as **AscendAPI**. "V1" is a 1,500-exercise dataset with one 180×180 GIF per
exercise. Its code and GIFs are in a GitHub repo labelled AGPL-3.0, but **AscendAPI's own V1 documentation
says the free dataset is for non-commercial use only and requires attribution**. Commercial use needs a paid
plan, and the V1 paid RapidAPI listing linked from the docs now returns "API not found". Separately, the
visual and naming evidence in section 4 suggests the animations are **Gym visual** artwork, and no ExerciseDB
or AscendAPI source mentions any licence from Gym visual. The repo's AGPL label therefore cannot be relied on
for the media. **Self-hosting the V1 GIFs in a commercial App Store app is not safe.**

### Facts with citations
- [F] The open-source V1 lives at https://github.com/bootstrapping-lab/exercisedb-api. GitHub reports AGPL-3.0. Its description: "Open Source ExerciseDB API … 1500+ exercises". It contains `src/data/exercises.json` (1,500 records) and `media/` (1,500 GIFs). The GIF I sampled (`media/01qpYSe.gif`) is 180×180.
- [F] Commit history:
  - 2025-08-01 `736813ad` "chore(license): switching to AGPL-3.0" replaced "MIT License … Copyright (c) 2024 ExerciseDB API".
  - Same day, `be74918e` "release ExerciseDB v1 GIFs as open source … Includes complete GIF library".
  - Its `package.json` still points to `https://github.com/exercisedb/exercisedb-api`.
  - https://github.com/bootstrapping-lab/exercisedb-api/commits/main
- [F] The current `ExerciseDB/exercisedb-api` repo was recreated 2025-11-25 with only `LICENSE` (AGPL-3.0) and a README for V2. Its homepage is ascendapi.com. https://github.com/ExerciseDB/exercisedb-api
- [F] The V1 hosted API's OpenAPI description (https://oss.exercisedb.dev/swagger, rendered at https://oss.exercisedb.dev/docs) contains a "⚠️ Usage Restrictions" table:
  - "✅ Allowed | Personal projects, prototypes, educational tools, non-commercial apps, community-driven fitness platforms"
  - "❌ Not allowed | Commercial products, SaaS platforms, or any monetised use without a paid plan via RapidAPI"
  - "📝 Attribution | Credit to AscendAPI is required when using this dataset in any project"
  - "🖼️ Media | Limited to 180p GIF format only"
  - Its servers entry says: "• Non-commercial use only • Attribution required".
- [F] The same description links "Need full v1 Dataset Access | Download Now" → https://go.exercisedb.dev/shop (redirects to https://shop.ascendapi.com/).
- [F] AscendAPI's docs: V1 is "Available as a free hosted tier and a paid RapidAPI tier". The paid tier is `edb-with-gifs-and-images-by-ascendapi`, with 360p–1080p GIFs. https://docs.ascendapi.com/products/edb-v1/overview
- [F] On 2026-10-18 that RapidAPI listing (https://rapidapi.com/ascendapi/api/edb-with-gifs-and-images-by-ascendapi/pricing) returned "Page Not Found — API not found."
- [F] The V1 bench press record: `"exerciseId": "EIeI8Vf", "name": "barbell bench press", "gifUrl": "https://static.exercisedb.dev/media/EIeI8Vf.gif"`. https://docs.ascendapi.com/products/edb-v1/overview
- [F] A GitHub code search for "gymvisual" or "gym visual" in `bootstrapping-lab/exercisedb-api` and the `ExerciseDB` org returned 0 hits. No AscendAPI page I read names the creator of the media.

### What it allows for us
- [F] Under AscendAPI's stated terms: personal or prototype use, with credit to AscendAPI.
- [I] Fine for a private design prototype. Not for the TestFlight beta, if we want to be strict that a public beta of a future paid app is "commercial products"; and not for the App Store release.

### Blockers / risks
- [F] **Non-commercial only** (the provider's own docs).
- [I] **Conflicting licence signals.** AGPL on the repo vs. "non-commercial" in the docs. The licensor's narrower statement is the safer reading, and AGPL is a software licence ill-suited to artwork anyway.
- [I] **Chain-of-title risk.** The GIFs appear to be Gym visual renders (section 4). If so, ExerciseDB's right to release them under AGPL is doubtful, and Gym visual's licence forbids licensees from redistributing. An AGPL label from ExerciseDB would not protect us against the copyright owner.
- [F] Only 180p media in the free tier.

### Open questions
- Does AscendAPI hold a redistribution licence from Gym visual, or is it the same rights holder? Neither has said so publicly. Ask both in writing before any use.
- What does shop.ascendapi.com sell for "full v1 Dataset Access", and on what licence? Not reviewed.

---

## 3. ExerciseDB V2 (AscendAPI "EDB with Videos and Images" on RapidAPI)

### Summary
V2 is AscendAPI's paid API: 11,000+ exercises, 15,000+ MP4 videos and 20,000+ images, sold only through
RapidAPI. Its Terms of Use are a **strict real-time, no-storage licence**:
- Nothing may be stored on devices or servers, and caching beyond about 1 hour is banned.
- Every use must be fetched fresh.
- When the subscription ends, all use stops and apps using the API must be discontinued.
- AscendAPI claims exclusive ownership of all media.

Both public plans say "Caching Allowed ✗". The free plan's media is watermarked. Pro is $100/month for 80k
requests. **Verdict: V2's terms block our design.** No offline gym use, no R2 mirror, no on-device cache, and
a perpetual dependency on a $100/month subscription with no exit. It also carries the same Gym-visual
provenance question as V1.

### Facts with citations
**Terms of Use**, published on the RapidAPI listing's Overview tab: https://rapidapi.com/ascendapi/api/edb-with-videos-and-images-by-ascendapi (read 2026-10-18)
- [F] §1: "All rights are reserved by AscendAPI. All data and content served by the EDB with Videos and Images by AscendAPI ("the API") are the exclusive property of AscendAPI. This includes … text, metadata, images, GIFs, videos …"
- [F] §2: "a non-exclusive, non-transferable, and revocable license … strictly limited to the duration of the subscription period".
- [F] §3 "Strict Storage Prohibition":
  - "Subscribers are strictly prohibited from storing any data, content, or media obtained from the API, including … Images and GIFs; Videos and audio content; Exercise descriptions and instructions …"
  - "Data and content cannot be stored: Locally on devices, computers, or mobile applications; On servers, databases, or cloud storage systems; In cache beyond temporary operational needs (not exceeding 1 hour); In any form of persistent storage or archival system."
  - "All data and content must be freshly requested from the API for every use. Unauthorized downloading, scraping, or bulk collection of data from this API is strictly prohibited."
- [F] §4 Termination: when a user stops their subscription or fails to pay, "all rights … are immediately revoked". Subscribers must "Cease all use … immediately; Delete any temporarily cached data within 24 hours; Remove any references to or derivatives of the API content; **Discontinue any applications or services that utilize the API**".
- [F] §5 Prohibited: "Storing, archiving, or retaining copies …; Creating backups …; Redistributing, reselling, or sublicensing …; Using the data and content beyond the active subscription period; … Creating derivative works that incorporate API content beyond active subscription".
- [F] §6 "Real-Time Access Only": "Fetch data fresh from the API for each request … Not rely on stored or cached versions of the content".
- [F] §7: violations "may result in immediate account suspension and legal action". §10: AscendAPI may modify the terms at any time, and continued use means acceptance. §12: governed by "applicable laws".
- [F] The terms contain **no attribution requirement**, no IP warranty and no indemnity for subscribers.
- [F] The listing links its product website to https://v2.exercisedb.dev and support to support@exercisedb.dev.

**Pricing** (https://rapidapi.com/ascendapi/api/edb-with-videos-and-images-by-ascendapi/pricing, 2026-10-18)

| Plan | Price | Requests | Library size | Watermarked media | Caching allowed | Rate limit | Bandwidth |
|---|---|---|---|---|---|---|---|
| Basic | $0/mo | 2,000/mo, hard limit | 200 | ✓ (yes, watermarked) | ✗ | 1,000/hour | 10,240 MB/mo, then $0.001/MB |
| Pro | $100/mo | 80,000/mo, then $0.002 each | 500 | ✗ | ✗ | none | 10,240 MB/mo, then $0.001/MB |

- [F] Both plans tick Videos and Images, and mark "Custom Enterprise Plan", "3D Exercise Videos" and "Descriptive Step Images" with ✗.

**AscendAPI docs**
- [F] "Caching of AscendAPI data is only permitted if your current plan explicitly allows it. … If your plan does not permit caching, you must not store any data returned by the API." Also: "Media asset URLs rotate every week on Monday at 00:00 UTC", and "Even if your plan allows caching, never store media asset URLs permanently." Persistent storage and bulk downloads are available "contact us" only. https://docs.ascendapi.com/guides/caching
- [F] "Both free and paid tiers are accessed via RapidAPI. The only difference is that free tier media is watermarked." Media: 11,000+ exercises, 20,000+ images (360p–1080p webp) and 15,000+ MP4 videos. https://docs.ascendapi.com/products/edb-v2/overview
- [F] Rate limits: free plans get 1,000 requests/hour. On paid plans, "our AI system monitors usage patterns". https://docs.ascendapi.com/guides/ratelimiting

**The other "ExerciseDB"** (a different owner; included to avoid confusion)
- [F] RapidAPI listing "ExerciseDB" by "Justin", 51,239 subscribers: "The original ExerciseDB … over 1300 exercises with … animated demonstrations". Plans: BASIC $0, PRO $12.99, ULTRA $18.99, MEGA $30.99. Also: "One-time payment options: https://www.exercisedb.io/". https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb
- [F] Its API Terms of Use (last updated June 8, 2026; site © DevWorx Consulting, LLC):
  - §4: "Caching of data and content from the ExerciseDB API is strictly prohibited."
  - §5: no redistribution, and no competing product.
  - §10: disclaims "non-infringement".
  - §12: the subscriber indemnifies them, including for "infringement or misuse of third-party rights".
  - https://edb-docs.up.railway.app/docs/api-terms-of-use
- [F] exercisedb.io ("EDB Exercise Intelligence") sells a self-hosted file licence:
  - Starter $199 / Pro $599, one-time.
  - 1,394 exercises, with "180x180 / 360x360 / 720x720 / 1080x1080 animated GIF" tiers.
  - "Platform-neutral commercial license".
  - https://exercisedb.io/pricing
- [F] Its terms say: "non-exclusive, non-transferable, platform-neutral license"; GIFs may be displayed "only in conjunction with" the data and "not as standalone content"; IP "remain[s] the property of ExerciseDB.io or its content suppliers"; governed by US law. https://exercisedb.io/terms
- [F] Its FAQ claims ExerciseDB.io is "the original creator and owner". https://exercisedb.io/faq

### What it allows for us
- [F] Live, online-only display of V2 media in a paid app while subscribed, with at most a 1-hour operational cache.
- [I] The API key must not ship in the app. Calls would go through our Worker, and media would load from the rotating CDN URLs.

### Blockers / risks (V2)
- [F] **No on-device storage and no server storage**, and caching is capped at 1 hour. That kills offline gym use, pre-loading for the in-workout pop-up across sessions, and any R2 mirror.
- [F] **Licence ends with the subscription.** We would have to "Discontinue any applications or services that utilize the API". That is a lock-in with no exit for a free beta and a hard cost floor ($100/mo for unwatermarked media) once paid.
- [F] The free plan's media is watermarked and its library is capped at "200". [I] A Pro library of "500" vs. the advertised 11,000+ is unexplained and needs clarifying.
- [F] Terms can change unilaterally. [I] The terms offer no IP warranty, while the media appear to be Gym visual work (section 4). Chain-of-title risk sits with us.
- [I] The exercisedb.io one-time licence is commercially workable on paper: self-hosted, perpetual, GIFs from 180 to 1080 px. But it raises the same provenance question, its terms acknowledge "content suppliers", and it gives no IP warranty.

### Open questions
- Does AscendAPI offer a written enterprise licence for persistent storage, and at what price?
- What do "Exercise Library Size 200/500" mean?
- Do AscendAPI and exercisedb.io each hold a written redistribution licence from Gym visual? Get it in writing before paying either.

---

## 4. Gym visual (gymvisual.com)

### Summary
Gym visual is a one-person commercial studio (© Aliaksandr Makatserchyk) selling 3D-rendered exercise
illustrations, GIFs (180 to 1080 px) and 1080p videos per item. Its licence **explicitly permits use in
Android or iOS apps**, is perpetual and royalty-free, and forbids redistribution, resale, AI training or
generation, and assigning rights to others. Several independent signals suggest that ExerciseDB's media
(V1, V2 and exercisedb.io) are Gym visual renders:
- matching IDs ("0025" = Barbell Bench Press),
- identical resolution tiers,
- a third-party dataset that credits Gym visual for ExerciseDB-ID-named GIFs,
- a visual match on the bench press render.

No primary source states that ExerciseDB is licensed by Gym visual. **For a commercial app, buying directly
from Gym visual is the clean licensing route for this art style.**

### Facts with citations
- [F] About page: "workout animations, GIFs and illustrations - to help trainers, mobile app and websites developers … Content created by Aliaksandr Makatserchyk". https://gymvisual.com/content/4-about-us
- [F] Licence: "Non-Exclusive Commercial Royalty-Free License (N-CRFL)". Key terms (https://gymvisual.com/content/9-license):
  - "you pay for the Media only once"; "granted in perpetuity and it is worldwide valid".
  - Granted "ONLY for the non-watermarked Media you buy; all the other versions (small watermarked and non-watermarked thumbnails which are visible on the public site) are entirely copyrighted".
  - Permitted: "to illustrate and visually enhance: Android or iOS mobile application (apps)".
  - May NOT be used "to resell or redistribute", "to use in products … destined for resale (i.e. image, video products…)", "to use in products or services that antagonizes Gym visual business model", or for AI training or generation. Also no NFTs, and not "to assign rights to third parties" or "to make available on a website for download".
  - "Buying the high-resolution Media … does not transfer the copyright. You may not … sell, license for use, or in any way distribute the Media for reuse."
  - The page states **no attribution requirement**.
- [F] Terms: "All Media … are owned by Aliaksandr Makatserchyk." If a licence is revoked you must "delete all Media and all copies". https://gymvisual.com/content/3-terms-and-conditions-of-use
- [F] Prices (2026-10-18). Each item also has a "Basic grey" / "Full color" style option.
  - "Barbell Bench Press", Reference **0025**, illustration: **$3.00** ("Less than $0.75 per 1 illustration after 10 items in cart"). https://gymvisual.com/illustrations/43-barbell-bench-press.html
  - Reference **002513**, animated GIF: **$3.60** ("$0.9 per 1 animated GIF after 10 items in cart"). "Resolution: 180x180 (extrasmall), 360x360 (small), 720x720 (medium), 1080x1080 (large)". https://gymvisual.com/animated-gifs/1519-barbell-bench-press.html
  - Reference **002512**, video: **$10.00** ("$6 per 1 video after 5 items in cart"). "Format: MOV … Resolution: 1920 x 1080 … 6s … Motion JPEG". https://gymvisual.com/videos/1342-barbell-bench-press.html
  - The search for "barbell bench press" alone returned 140 products. The "Pack" category showed "no products" on 2026-10-18.

**Evidence linking ExerciseDB media to Gym visual**
- [F] A third-party dataset (https://github.com/hasaneyldrm/exercises-dataset, 1,324 exercises, ~22.9k stars):
  - Names its bench press file `videos/0025-EIeI8Vf.gif`, which combines the Gym visual / legacy-ExerciseDB ID `0025` with ExerciseDB V1's ID `EIeI8Vf`.
  - Its NOTICE.md says: "The exercise media … is the property of Gym visual and is redistributed here with permission", restricted to 180×180 with the credit "© Gym visual — https://gymvisual.com/".
  - This is a third party's claim, not a statement by ExerciseDB or Gym visual.
- [F] The resolution tiers match exactly. Gym visual sells 180/360/720/1080 GIFs. ExerciseDB V1 free is "180p GIF" and V1 paid is 360p–1080p (docs.ascendapi.com). exercisedb.io sells 180/360/720/1080.
- [I] Visual comparison, done by me: the ExerciseDB V2 bench press image (`https://cdn.exercisedb.dev/media/images/CNKJtB2O5Y.webp`, from the AscendAPI docs) and Gym visual's 002513 GIF preview show what looks like the same render: same grey figure, red pectorals, white rack, pose and camera angle. The V1 180p GIF (`EIeI8Vf.gif`) uses the same style from a different angle.
- [F] The coordinator observed a Lyfta exercise page playing `GymvisualMP4/00251201.mp4`. I did not verify this. It is consistent with the `0025…` reference scheme above.
- [F] No AscendAPI or ExerciseDB source names Gym visual (GitHub code search: 0 hits). AscendAPI's V2 terms claim "exclusive property". exercisedb.io's terms say "ExerciseDB.io or its content suppliers".

### What it allows for us
- [F] Buy the GIFs or videos we need and use them inside the iOS app, perpetually, with no royalties. No attribution is required, though a credit is good practice.
- [I] Bundling in the app binary, or serving from our own R2 to our own app, counts as using the media "to illustrate … iOS mobile application". It is not "redistribution" provided users cannot download the raw files for reuse.

### Blockers / risks
- [I] **Public GitHub repo.** Purchased files must **not** be committed to the public repo. That would be redistribution, or "make available on a website for download". Keep them in private R2 or a private asset pipeline, and serve them only to the app.
- [I] Cost scales with library size. For example, 300 exercises × ~$0.90 per GIF after bulk discount is about $270+. Videos at ~$6 each after 5 items would be about $1,800 for 300.
- [F] "Antagonizes Gym visual business model" is vague. [I] An exercise-library app is plainly within the "mobile app developers" audience Gym visual targets.
- [I] Does a per-item purchase cover delivery from our server as well as from the app bundle? It very likely does, but ask support to confirm. Gym visual's licence invites emails for uncertain uses.

### Open questions
- Do the per-item purchases include all four GIF sizes? The data sheet lists four sizes, which suggests yes.
- Is there a bulk or whole-library licence price? The Pack category is empty.
- Will Gym visual confirm in writing that serving from our own CDN to our app is permitted? Will it confirm whether ExerciseDB / AscendAPI / exercisedb.io are authorised resellers?

---

## 5. YouTube embeds in an iOS app (IFrame Player API in WKWebView)

### Summary
Embedding is allowed and free. Using the embedded or IFrame player **does** bring us under the YouTube API
Services Terms, the Developer Policies and the Required Minimum Functionality. The practical obligations are:
- a privacy policy linking Google's, and our terms linking YouTube's ToS;
- a player at least 200×200 px with nothing overlaid;
- a correct `Referer` (our bundle ID) or the player fails with error 153;
- no downloading, caching or offline playback;
- **no charging users to watch embedded videos**, which matters if form videos ever sit behind a subscription;
- coping with owners who disable embedding (errors 101/150) or delete videos.

### Facts with citations
**Are we bound?**
- [F] The ToS defines YouTube API Services as "the YouTube API services (e.g., YouTube Data API service and YouTube Reporting API service)". The definition is non-exhaustive. https://developers.google.com/youtube/terms/api-services-terms-of-service (last updated 2026-09-14)
- [F] The Developer Policies call "The YouTube IFrame Player API service, which lets you embed videos in a website" an API service (III.D.2) and list the "YouTube embedded player" in III.D.1. https://developers.google.com/youtube/terms/developer-policies (last updated 2026-10-15)
- [F] The Required Minimum Functionality says "API Clients that use the YouTube embedded player (including the YouTube IFrame Player API) must provide identification through the HTTP Referer request header". https://developers.google.com/youtube/terms/required-minimum-functionality (last updated 2026-10-15)
- [F] The YouTube ToS for end users: "You may also show YouTube videos through the embeddable YouTube player." https://www.youtube.com/t/terms (effective December 15, 2023)

**Privacy and legal notices** (Developer Policies III.A)
- [F] III.A.1: API Clients "must display a link to YouTube's Terms of Service", and our terms must say users are bound by them.
- [F] III.A.2: the privacy policy must "be prominently displayed and easily accessible to users at all times". It must "notify users that the API Client uses YouTube API Services" and "reference and link to the Google Privacy Policy" (http://www.google.com/policies/privacy). It must also "disclose, if it does so, that the API Client stores, accesses or collects … including by placing, accessing or recognizing cookies or similar technology on users' devices or browsers", and "explain how users can contact" us.
- [F] ToS §7: "Each API Client will provide and adhere to a published privacy policy."
- [F] III.E.4.i: "When your API Client loads, it collects and shares some basic user data with YouTube".
- [F] III.E.4.j: "API Clients must look up the Made For Kids status of each YouTube video that it embeds … For each video that is designated Made For Kids, API Clients must turn off tracking".

**Player rules** (Required Minimum Functionality; IFrame API reference; Developer Policies)
- [F] "Embedded players must have a viewport that is at least 200px by 200px." The page recommends 16:9 players be at least 480×270. Sources: RMF, and https://developers.google.com/youtube/iframe_api_reference
- [F] "You must not display overlays, frames, or other visual elements in front of any part of a YouTube embedded player." (RMF)
- [F] Autoplay must not start until the player is visible and more than half of it is on screen. There must not be "more than one YouTube player that automatically plays content simultaneously". (RMF)
- [F] Policies III.I.4–9 forbid us to:
  - "modify, build upon, or block any portion or functionality of a YouTube player";
  - remove or obscure player links;
  - block ads;
  - "separate, isolate, or modify the audio or video components";
  - play from "a background player".
- [F] III.I.21 forbids nesting the player "in a nested or hierarchical iframe lineage".
- [F] Referer in WebViews (RMF):
  - For local HTML, set the `baseURL` (`loadHTMLString:baseURL:`).
  - For a direct embed URL, add a Referer header in `loadRequest:`.
  - The Referer should use HTTPS with the app's bundle ID as the domain (reverse-DNS).
  - `SFSafariViewController` can't set a Referer, so use the `origin` parameter there.
- [F] IFrame `onError` 153: "The request does not include the HTTP Referer header or equivalent API Client identification." (IFrame API reference)
- [F] `playsinline`: "controls whether videos play inline or fullscreen on iOS" (fullscreen by default). `rel=0` now only limits related videos to the same channel. https://developers.google.com/youtube/player_parameters

**Offline and caching**
- [F] III.E.1: we must not "download, import, backup, cache, or store copies of YouTube audiovisual content without YouTube's prior written approval", or "make content available for offline playback".

**Money**
- [F] III.F.3.a: "API Clients must not charge users to watch content in an embedded YouTube player."
- [F] III.F.3.b: we "must not otherwise gate access to a video by requiring a user to take an action other than clicking the play button".
- [F] III.G.2.a permits "Selling an API Client". III.G.1.c forbids selling ads "placed on or within YouTube audiovisual content".

**Which videos can be embedded**
- [F] Creators can untick "Allow embedding" in YouTube Studio. https://support.google.com/youtube/answer/171780
- [F] IFrame `onError` 101/150: "The owner of the requested video does not allow it to be played in embedded players." Error 100 means removed or private.
- [F] "Age-restricted videos can't be watched on most 3rd party websites." Privacy-enhanced mode (youtube-nocookie) "is available only for embedded players on websites". (Help article above)

**App Store**
- [F] 5.2.2: "If your app uses, accesses, monetizes access to, or displays content from a third-party service, ensure that you are specifically permitted to do so under the service's terms of use."
- [F] 5.2.3: apps should not "save, convert, or download media from third-party sources (such as … YouTube …) without explicit authorization".
- [F] 5.1.1(i): a privacy policy link is required in App Store Connect and in the app.
- Source: https://developer.apple.com/app-store/review/guidelines/

### What it allows for us
- [I] A curated list of video IDs, played on demand in a ≥200×200 inline WKWebView player with correct Referer and `playsinline=1`, is compliant. It works on an exercise detail screen and in a workout pop-up, provided the pop-up keeps the player fully visible and un-overlaid.

### Blockers / risks
- [I] **Paywall conflict.** If a future subscription unlocks "form videos" made of YouTube embeds, that arguably breaches III.F.3.a. Keep YouTube embeds free to all users; paying for the app itself is OK under III.G.2.a.
- [F] **No offline use**, which matters for gyms with poor signal.
- [I] **Link rot and control.** Third-party videos can be deleted, made private, age-restricted or have embedding disabled at any time. The app needs graceful fallbacks for errors 100/101/150/153.
- [I] **Made-for-Kids lookup.** III.E.4.j implies a YouTube Data API call (API key and quota) per embedded video. A one-time server-side check in our Worker when curating IDs is the likely way to meet it.
- [I] **Privacy disclosures.** Embedding sends data to Google, including cookies. Our privacy policy and the App Store privacy "nutrition label" must reflect that.
- [I] A WKWebView player inside a SwiftUI sheet must avoid our own controls or gradients on top of it. Each RMF version tightens the rules, so recheck before release.

### Open questions
- Will we curate only videos from channels that permit embedding, and ideally ask those channels' permission? The policies are silent on the creator relationship, but courtesy reduces link-rot risk.
- Is a single "Watch on YouTube" deep link (opening the YouTube app) simpler for the pop-up? [I] It avoids most player rules. The detail screen could still embed.

---

## 6. Muscle maps (front/back anatomy, primary vs. secondary colouring, small silhouettes)

### Summary
wger's muscle highlight SVGs are derived from two Wikimedia Commons diagrams licensed **CC BY-SA 3.0**
(author "Termininja"). They are usable commercially with attribution, but our recoloured or edited versions
must stay BY-SA, and the wger API carries no licence fields for them. A public-domain alternative is Mikael
Häggström's labelled muscle diagrams, which are PNGs based on Gray's Anatomy. An MIT-licensed SVG body
model exists in `react-native-body-highlighter` and is easy to recolour, but the origin of its art is
undocumented. [I] Best options: (a) wger/Commons SVGs with BY-SA credit, publishing our recoloured derivatives
in the public repo; or (b) draw our own silhouettes, traced from public-domain references, and own them outright.

### Facts with citations
- [F] The wger muscle endpoint returns `id`, `name`, `name_en`, `is_front`, `image_url_main` and `image_url_secondary` (SVG). It has **no licence fields**. There are 15 muscles. https://wger.de/api/v2/muscle/?limit=2
- [F] wger's `wger/core/static/images/muscles/SOURCES` lists only https://commons.wikimedia.org/wiki/File:Muscular_system-back.svg and https://commons.wikimedia.org/wiki/File:Muscular_system.svg. https://github.com/wger-project/wger/blob/master/wger/core/static/images/muscles/SOURCES
- [F] Commons metadata for both files: LicenseShortName "CC BY-SA 3.0", Artist "Termininja", AttributionRequired true, 1000×1400, created 2012-08-13. The "Credit" field lists source images such as `Pectoralis_major.png`, `Latissimus_dorsi.png` and `Gastrocnemius.png`, so they are derivatives. Commons API (`prop=imageinfo&iiprop=extmetadata`).
- [F] https://commons.wikimedia.org/wiki/File:Muscles_anterior_labeled.png: "Public domain", Artist Mikael Häggström, AttributionRequired false, Credit "Gray's Anatomy plates of muscles". (The posterior counterpart's title did not resolve in my query; not checked.)
- [F] https://github.com/HichamELBSI/react-native-body-highlighter is MIT ("Highlight human body parts with SVG only"). https://github.com/giavinh79/react-body-highlighter is MIT, and "The SVG polygons were leveraged from" the React Native package. Neither README states where the original body art came from.

### What it allows for us
- [I] wger/Commons SVGs:
  - Commercial use with credit ("Muscle diagrams based on 'Muscular system' by Termininja, Wikimedia Commons, CC BY-SA 3.0", with links).
  - Recoloured primary/secondary layers are adaptations and must be CC BY-SA 3.0 or later (4.0 is allowed by BY-SA 3.0's compatibility clause).
  - Publish those SVGs in the public repo.
- [I] The MIT body highlighter allows commercial use if we keep the MIT notice. No share-alike. Ideal for colourable silhouettes, if provenance holds.

### Blockers / risks
- [I] BY-SA on our recoloured anatomy assets means competitors can reuse them. That is acceptable for an open repo.
- [I] Upstream provenance of the Commons derivatives (Credit lists other Commons PNGs) and of the MIT SVG paths is unverified. Low risk, but check the Commons source files' licences before shipping.

### Open questions
- Should the small browse-by-muscle silhouettes be our own drawings? [I] Simplest licensing story, and they are small vector shapes.

---

## 7. Other clearly licensed sources (brief)

| Source | Licence (primary) | Media | Notes |
|---|---|---|---|
| **Everkinetic** (https://github.com/everkinetic/data) | CC BY-SA 4.0 (`LICENSE.md`) | ~550 exercises × 2 frames ("relaxation" / "tension"): 1,109 SVG + 2,196 PNG | Clean vector line art, already the largest single credited source in wger. [I] Two frames can be cross-faded into a simple "animation". BY-SA as in wger. |
| **free-exercise-db** (https://github.com/yuhonas/free-exercise-db) | Unlicense ("Open Public Domain") | 800+ exercises, ~1,750 JPG stills | Derived from https://github.com/wrkout/exercises.json (Unlicense). [I] **Image provenance is not documented.** A public-domain dedication by a repo owner only covers what they own, so I would not rely on these photos without provenance. |
| **wrkout.xyz** | Commercial (mentioned in wrkout README: "2,500+ exercises, 10,000+ images … 3,500+ videos … can be used in commerical projects") | — | Not reviewed. Listed only as a lead. |
| **Gym visual** | Commercial N-CRFL (section 4) | Per-item GIF/video/illustration | Cleanest route to the "ExerciseDB look". |

I found no well-sourced CC0 or CC-BY *video* library of gym exercise demonstrations with meaningful coverage.
Self-filming (our own CC-BY or proprietary clips) or Gym visual purchases are the realistic paths to broad video coverage.

---

## 8. Comparison table

| Source | Metadata licence | Media licence | Commercial app OK? | Caching / re-hosting OK? | Attribution needed | Video coverage |
|---|---|---|---|---|---|---|
| **wger** | Per record. Sampled: CC BY-SA 4.0 (exercise + translations) | Per item: CC BY-SA 4.0 (295 images, all 78 videos) / CC BY-SA 3.0 (88 images) | **Yes** | **Yes** (licence permits; no API rule against; ship from R2) | **Yes**, per item (TASL fields). Our edits/translations → BY-SA | 46 / 932 exercises (78 videos, one author, 1080p HEVC MOV). Images on 279 exercises; 5 animated GIFs |
| **ExerciseDB V1** (AscendAPI free) | Repo: AGPL-3.0. Docs: non-commercial | Repo says AGPL. Docs: "Non-commercial use only". Likely Gym visual art; no licence shown | **No** (provider's docs) | Self-host technically possible; **not** for commercial use | Yes (credit AscendAPI) | None (1,500 × 180p GIFs) |
| **ExerciseDB V2** (AscendAPI, RapidAPI) | Proprietary, "exclusive property of AscendAPI" | Proprietary, subscription-bound; free tier watermarked | Only while subscribed, online-only ($100/mo Pro) | **No.** No device/server storage, ≤1 h cache, delete on termination | Not required by ToS | 15,000+ MP4 claimed (plan "library size" 200/500 unclear) |
| **exercisedb.io / "original" ExerciseDB** (Justin / DevWorx) | Proprietary | Proprietary. One-time file licence $199/$599 (180–1080 px GIFs); API forbids caching | File licence: yes (per its terms). API: online only | File licence: self-host OK, no redistribution. API: **no** caching | Not stated; must not remove notices | None (GIFs only; 1,394 exercises) |
| **Gym visual** | n/a (media vendor) | Proprietary N-CRFL, perpetual, per item (GIF $3.60, video $10, discounts in bulk) | **Yes** (iOS apps explicitly allowed) | Bundle/serve to our app: yes [I]. **Not** in the public repo, not downloadable | Not required | Per item. 1080p MOV videos exist (e.g. bench press 002512) |
| **YouTube embeds** | n/a | Each video's owner; YouTube ToS + API policies | Yes, but **must not charge to watch** embeds | **No** (no download/cache/offline) | YouTube branding stays intact; privacy policy links Google; terms link YouTube ToS | Whatever we curate; owners can disable embedding or delete |
| **Muscle maps: wger / Commons SVG** | n/a | CC BY-SA 3.0 (Termininja) | Yes | Yes | Yes; our recolours → BY-SA | n/a |
| **Muscle maps: Häggström PNGs** | n/a | Public domain | Yes | Yes | No (courtesy cite) | n/a |
| **Muscle maps: body-highlighter SVG** | n/a | MIT (art provenance undocumented) | Yes | Yes | Keep MIT notice | n/a |
| **Everkinetic** | CC BY-SA 4.0 | CC BY-SA 4.0 | Yes | Yes | Yes; edits → BY-SA | None (2-frame line art, ~550 exercises) |

### Bottom line [I]
1. **wger (plus Everkinetic) is the only free, clearly licensed source.** Use it now: sync to R2 and add a credits UI. It is good for names and metadata and gives partial still-image coverage, but video coverage is poor.
2. **Do not use ExerciseDB V1 commercially, and do not build on V2.** V2's storage ban and "discontinue on termination" clause are incompatible with an offline-capable gym logger and with a free beta.
3. **For the polished 3D animation look, license directly from Gym visual**, per item, in the exercises we actually ship. Keep the files private (R2, not the public repo), and get written confirmation of server delivery.
4. **YouTube embeds** suit optional "watch a coach explain it" links. Keep them free to all users, online only, with privacy-policy and ToS-link updates.
