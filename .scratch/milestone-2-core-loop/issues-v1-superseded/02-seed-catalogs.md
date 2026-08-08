# 02 — Seed exercise & equipment catalog

**What to build:** On first launch the store is populated with the seeded exercise list (with load types and equipment tags) and a starter equipment-model catalog (major manufacturers, popular lines — small at first, grown alongside development). The Exercises tab shows this real seeded data. Seeded entries carry stable catalog identifiers that survive app updates; user-created entries are distinguishable from seeded ones.

**Blocked by:** 01 — SwiftData schema & persistent store.

**Status:** ready-for-agent

- [ ] First launch seeds exercises and equipment models exactly once; relaunch does not duplicate
- [ ] Each catalog model links to one or more exercises (multi-exercise stations link to several)
- [ ] Seeded vs user-created is queryable (isSeeded flag or separate ID space per SPEC)
- [ ] Exercises tab lists seeded exercises with load-type badges from the store, not SampleStore
