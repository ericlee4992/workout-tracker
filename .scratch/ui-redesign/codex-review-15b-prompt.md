Round 2 (T6) of ticket 15: (1) the cause is labelled suspected in StartWorkoutView.swift's comment
and the ticket; (2) the ticket has the job/state sentence, the wireframe (ticket 11's plus the
row) and the tells; (3) your advisory taken — TemplateDetailView has a view-owned `deleted`
flag set before the service deletes, gating `items` and the title. Boundary main..HEAD on
templates-15-delete-in-detail (HEAD = the new commit). The full UI suite is running on the
previous commit; TemplateDetailUITests and the template captures will be rerun on this one and
recorded before merge. Do NOT run xcodebuild or simctl; do not modify source files. One
paragraph: "clear" or what is missing. Write to .scratch/ui-redesign/codex-review-15b.md
