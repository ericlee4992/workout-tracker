# 06 — Private device trial and recognition acceptance

Type: task
Status: ready-for-human — installation prechecks and gym evidence outstanding

Software scope and decisions: [spec](../spec.md), D56–D58. Signed build prepared; current phone still has `8c71d27`. No installation is inferred from build/signing success.

## Next action

Confirm the existing app opens and old workouts remain intact. Obtain a fresh export/container backup before installing the schema-11 build; follow DEVELOPMENT signing/freshness/launch procedure. Profiles currently expire September 24 at 07:16 UTC. Enter the OpenAI key in the new app’s Settings after installation; the tooling key saved on the Mac is not bundled or automatically provisioned to the phone.

## Physical acceptance

- Labels and whole strength machines: verify proposed movement, visible brand/model evidence, generic fallback, retake and corrections on actual gym equipment. Two similar machines at a gym must remain distinct physical instances.
- Known limitation: the public g010 frontal whole-machine sample was misclassified across reasoning settings. This is not a recognition-accuracy pass. A printed generic movement title is now prevented from becoming a fabricated precise model even when AI labels it specific.
- Check first-use routine startup selects the sole compatible machine at the generating gym, remembers an existing compatible choice, and does not guess between several.
- Generate/review/edit a real weekly lifting/cardio routine; check available equipment and suitability. No starting weights are generated. Cardio starts only with an explicit tap; plans are not measured activity.
- Verify camera permission/denial, photo library, weak connection, API billing/authorization errors and cancellation on the phone. Simulator flows do not establish physical camera/GPS/HealthKit behavior.
- Existing [cardio physical acceptance](../../cardio/issues/02-device-acceptance.md) remains open separately. Restore testing remains unverified; public backend/App Store work and guides remain deferred.
