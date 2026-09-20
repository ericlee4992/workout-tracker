# Post-cardio migration fixture

`WorkoutTrackerTests/Fixtures/PostCardio.store` is synthetic, generated using product code from installed-source commit `8c71d27` in the `ai-schema-baseline` checkout. The temporary test source is preserved in this record directory. Generation passed 1 test, exit 0; its SQLite backup API snapshot has integrity `ok` and contains no private phone data.

Contains a model-less machine, two exercises, a superset template with per-slot reps, a finished mixed workout with a 70 kg/8 rep set and a 600-second run with entered 1.2 mi, and an unfinished outdoor walk. All pre-existing identities, relationships and entered values must survive additive AI migration. The unfinished walk recovers paused using established cardio behavior. Artifacts: ignored results/baseline.{log,xcresult}, baseline-exit.txt.
