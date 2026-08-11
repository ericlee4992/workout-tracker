#!/usr/bin/env python3
"""Regenerates WorkoutTracker/Resources/SeedCatalog.json (ticket 20).

The committed artifact is the JSON; this script is how it is (re)produced so a
future expansion can extend the catalog without hand-editing ~1000 rows.

    python3 scripts/generate_seed_catalog.py            # rewrite the JSON
    python3 scripts/generate_seed_catalog.py --check    # fail if JSON is stale

Model/exercise content lives in scripts/catalog_data.py, transcribed from the
research files kept under docs/catalog-sources/. Every model name there was read
off a manufacturer or authorised-dealer listing — nothing is extrapolated from a
naming pattern (see the ticket's "Accuracy is the whole point").

## UUID allocation (D24)

Catalog UUIDs are fixed forever: logged history is keyed on them. Ids are
allocated from two dense sequences,

    exercises        5EED0001-0000-4000-8000-0000000000NN
    equipment models 5EED0002-0000-4000-8000-0000000000NN

with NN a 1-based decimal index in allocation order. Allocation is *sticky*:
this script reads the currently committed JSON, reuses the id of every row whose
stable key it still finds, and only hands out fresh indices (continuing from the
highest one ever used) to genuinely new rows. Stable keys are the exercise
`name` and the model `manufacturer + modelName`. Consequences:

- reordering or removing entries in catalog_data.py never renumbers anything;
- a future expansion just appends and keeps counting from `nextIndex`;
- the 12 exercise + 24 model ids shipped in catalog version 1 are additionally
  pinned in LEGACY_* below and verified on every run.
"""

from __future__ import annotations

import argparse
import json

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from catalog_data import MANUFACTURERS  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
OUTPUT = REPO / "WorkoutTracker" / "Resources" / "SeedCatalog.json"

CATALOG_VERSION = 2

EXERCISE_NS = "5EED0001-0000-4000-8000-{:012d}"
MODEL_NS = "5EED0002-0000-4000-8000-{:012d}"

# ---------------------------------------------------------------------------
# Exercises
#
# (key, name, loadType, equipmentTypeTags, muscleGroup)
#
# `key` is what catalog_data.py links models to; it never reaches the JSON.
# muscleGroup vocabulary (ticket 21 groups the picker by it) — keep to this set:
#   Chest, Back, Shoulders, Biceps, Triceps, Forearms, Neck,
#   Quads, Hamstrings, Glutes, Hips, Calves, Core, Full Body
# The first 12 rows shipped in catalog version 1; their names are the stable id
# key, so they must not change (metadata may — "Legs"/"Arms" became the
# finer-grained groups below).
# ---------------------------------------------------------------------------

M = "machine"
C = "cable"
BB = "barbell"
DB = "dumbbell"
SM = "smith"
BW = "bodyweight"

EXERCISES = [
    # -- version 1 (ids 1–12, names frozen) ---------------------------------
    ("chestPress", "Seated Chest Press", "weighted", [M], "Chest"),
    ("latPulldown", "Lat Pulldown", "weighted", [M, C], "Back"),
    ("seatedRow", "Seated Row", "weighted", [M, C], "Back"),
    ("legPress", "Leg Press", "weighted", [M], "Quads"),
    ("shoulderPress", "Machine Shoulder Press", "weighted", [M], "Shoulders"),
    ("benchPress", "Bench Press", "weighted", [BB], "Chest"),
    ("squat", "Squat", "weighted", [BB], "Quads"),
    ("pullUp", "Pull-Up", "bodyweightPlus", [BW], "Back"),
    ("assistedPullUp", "Assisted Pull-Up", "assisted", [M], "Back"),
    ("dumbbellCurl", "Dumbbell Curl", "weighted", [DB], "Biceps"),
    ("tricepsPushdown", "Triceps Pushdown", "weighted", [C], "Triceps"),
    ("dip", "Dip", "bodyweightPlus", [BW], "Chest"),
    # -- new in version 2 ---------------------------------------------------
    ("inclineChestPress", "Incline Chest Press", "weighted", [M], "Chest"),
    ("declineChestPress", "Decline Chest Press", "weighted", [M], "Chest"),
    ("chestFly", "Chest Fly (Pec Deck)", "weighted", [M], "Chest"),
    ("cableCrossover", "Cable Crossover", "weighted", [C], "Chest"),
    ("inclineBenchPress", "Incline Bench Press", "weighted", [BB], "Chest"),
    ("declineBenchPress", "Decline Bench Press", "weighted", [BB], "Chest"),
    ("smithBenchPress", "Smith Machine Bench Press", "weighted", [SM], "Chest"),
    ("assistedDip", "Assisted Dip", "assisted", [M], "Chest"),
    ("pullover", "Pullover", "weighted", [M], "Back"),
    ("highRow", "High Row", "weighted", [M], "Back"),
    ("lowRow", "Low Row", "weighted", [M, C], "Back"),
    ("tBarRow", "T-Bar Row", "weighted", [M], "Back"),
    ("chestSupportedRow", "Chest-Supported Row", "weighted", [M], "Back"),
    ("bentOverRow", "Bent-Over Row", "weighted", [BB], "Back"),
    ("shrug", "Shrug", "weighted", [M], "Back"),
    ("deadlift", "Deadlift", "weighted", [BB, M], "Back"),
    ("backExtension", "Back Extension", "weighted", [M], "Back"),
    ("reverseHyper", "Reverse Hyperextension", "weighted", [M], "Glutes"),
    ("gluteHamRaise", "Glute-Ham Raise", "bodyweightPlus", [BW], "Hamstrings"),
    ("lateralRaise", "Lateral Raise", "weighted", [M], "Shoulders"),
    ("rearDeltFly", "Rear Delt Fly", "weighted", [M], "Shoulders"),
    ("overheadPress", "Overhead Press", "weighted", [BB], "Shoulders"),
    ("vikingPress", "Viking Press", "weighted", [M], "Shoulders"),
    ("rotatorCuff", "Rotator Cuff", "weighted", [M], "Shoulders"),
    ("neckExtension", "Neck Machine", "weighted", [M], "Neck"),
    ("bicepsCurl", "Machine Biceps Curl", "weighted", [M, C], "Biceps"),
    ("preacherCurl", "Preacher Curl", "weighted", [M, BB], "Biceps"),
    ("tricepsExtension", "Triceps Extension", "weighted", [M], "Triceps"),
    ("overheadTricepsExtension", "Overhead Triceps Extension", "weighted", [M, C], "Triceps"),
    ("seatedDip", "Seated Dip", "weighted", [M], "Triceps"),
    ("wristCurl", "Wrist Curl", "weighted", [M], "Forearms"),
    ("gripTrainer", "Grip Trainer", "weighted", [M], "Forearms"),
    ("legExtension", "Leg Extension", "weighted", [M], "Quads"),
    ("lyingLegCurl", "Lying Leg Curl", "weighted", [M], "Hamstrings"),
    ("seatedLegCurl", "Seated Leg Curl", "weighted", [M], "Hamstrings"),
    ("standingLegCurl", "Standing Leg Curl", "weighted", [M], "Hamstrings"),
    ("kneelingLegCurl", "Kneeling Leg Curl", "weighted", [M], "Hamstrings"),
    ("nordicCurl", "Nordic Hamstring Curl", "bodyweightPlus", [BW], "Hamstrings"),
    ("hackSquat", "Hack Squat", "weighted", [M], "Quads"),
    ("pendulumSquat", "Pendulum Squat", "weighted", [M], "Quads"),
    ("beltSquat", "Belt Squat", "weighted", [M], "Quads"),
    ("machineSquat", "Machine Squat", "weighted", [M], "Quads"),
    ("sissySquat", "Sissy Squat", "bodyweightPlus", [BW], "Quads"),
    ("lunge", "Lunge", "weighted", [M], "Quads"),
    ("stepUp", "Step-Up", "weighted", [M], "Quads"),
    ("smithSquat", "Smith Machine Squat", "weighted", [SM], "Quads"),
    ("hipThrust", "Hip Thrust", "weighted", [M], "Glutes"),
    ("gluteKickback", "Glute Kickback", "weighted", [M], "Glutes"),
    ("glutePress", "Glute Press", "weighted", [M], "Glutes"),
    ("legAbduction", "Leg Abduction", "weighted", [M], "Hips"),
    ("legAdduction", "Leg Adduction", "weighted", [M], "Hips"),
    ("multiHip", "Multi-Hip", "weighted", [M], "Hips"),
    ("calfRaise", "Calf Raise", "weighted", [M], "Calves"),
    ("standingCalfRaise", "Standing Calf Raise", "weighted", [M], "Calves"),
    ("seatedCalfRaise", "Seated Calf Raise", "weighted", [M], "Calves"),
    ("donkeyCalfRaise", "Donkey Calf Raise", "weighted", [M], "Calves"),
    ("tibialisRaise", "Tibialis Raise", "weighted", [M], "Calves"),
    ("abdominalCrunch", "Abdominal Crunch", "weighted", [M], "Core"),
    ("torsoRotation", "Torso Rotation", "weighted", [M], "Core"),
    ("hangingKneeRaise", "Hanging Knee Raise", "bodyweightPlus", [BW], "Core"),
    ("jammerPress", "Jammer Press", "weighted", [M], "Full Body"),
    ("sledPush", "Sled Push", "weighted", [M], "Full Body"),
]

MUSCLE_GROUPS = {
    "Chest", "Back", "Shoulders", "Biceps", "Triceps", "Forearms", "Neck",
    "Quads", "Hamstrings", "Glutes", "Hips", "Calves", "Core", "Full Body",
}

# The rows shipped in catalog version 1. Their ids must survive byte-identical
# or every logged workout referencing them is orphaned (D24).
LEGACY_EXERCISE_IDS = {name: EXERCISE_NS.format(i + 1)
                       for i, (_, name, *_rest) in enumerate(EXERCISES[:12])}
LEGACY_MODEL_COUNT = 24


def load_existing() -> dict:
    if not OUTPUT.exists():
        return {"version": 0, "exercises": [], "equipmentModels": []}
    return json.loads(OUTPUT.read_text())


def build() -> dict:
    existing = load_existing()
    exercise_ids = {e["name"]: e["id"] for e in existing["exercises"]}
    model_ids = {(m["manufacturer"], m["modelName"]): m["id"]
                 for m in existing["equipmentModels"]}

    def next_index(ids: dict, namespace: str) -> int:
        used = [int(value.rsplit("-", 1)[1]) for value in ids.values()]
        return max(used, default=0) + 1

    # --- exercises ---------------------------------------------------------
    exercise_index = next_index(exercise_ids, EXERCISE_NS)
    exercises = []
    key_to_id: dict[str, str] = {}
    for key, name, load_type, tags, muscle_group in EXERCISES:
        assert muscle_group in MUSCLE_GROUPS, f"{name}: unknown muscle group {muscle_group}"
        assert key not in key_to_id, f"duplicate exercise key {key}"
        uuid = exercise_ids.get(name)
        if uuid is None:
            uuid = EXERCISE_NS.format(exercise_index)
            exercise_index += 1
        key_to_id[key] = uuid
        exercises.append({
            "id": uuid,
            "name": name,
            "loadType": load_type,
            "equipmentTypeTags": tags,
            "muscleGroup": muscle_group,
        })

    # --- equipment models --------------------------------------------------
    model_index = next_index(model_ids, MODEL_NS)
    models = []
    seen: set[tuple[str, str]] = set()
    for manufacturer, entries in MANUFACTURERS:
        for model_name, links in entries:
            key = (manufacturer, model_name)
            assert key not in seen, f"duplicate model {manufacturer} / {model_name}"
            seen.add(key)
            link_keys = [k for k in links.split("+") if k]
            assert link_keys, f"{manufacturer} {model_name}: no exercise links"
            ids, deduped = [], set()
            for link in link_keys:
                assert link in key_to_id, f"{manufacturer} {model_name}: unknown exercise {link}"
                if link not in deduped:
                    deduped.add(link)
                    ids.append(key_to_id[link])
            uuid = model_ids.get(key)
            if uuid is None:
                uuid = MODEL_NS.format(model_index)
                model_index += 1
            models.append({
                "id": uuid,
                "manufacturer": manufacturer,
                "modelName": model_name,
                "exerciseIDs": ids,
            })

    catalog = {"version": CATALOG_VERSION, "exercises": exercises, "equipmentModels": models}
    verify(catalog, existing)
    return catalog


def verify(catalog: dict, existing: dict) -> None:
    """Guards the invariants a bad regeneration would silently break."""
    exercise_ids = [e["id"] for e in catalog["exercises"]]
    model_ids = [m["id"] for m in catalog["equipmentModels"]]
    assert len(set(exercise_ids)) == len(exercise_ids), "duplicate exercise id"
    assert len(set(model_ids)) == len(model_ids), "duplicate model id"
    assert not set(exercise_ids) & set(model_ids), "id reused across entity kinds"

    # Version-1 ids, pinned (D24).
    for name, uuid in LEGACY_EXERCISE_IDS.items():
        match = next((e for e in catalog["exercises"] if e["name"] == name), None)
        assert match and match["id"] == uuid, f"legacy exercise id moved: {name}"
    for index in range(1, LEGACY_MODEL_COUNT + 1):
        uuid = MODEL_NS.format(index)
        assert uuid in model_ids, f"legacy model id vanished: {uuid}"

    # Every id the previous JSON handed out is still present, on the same row.
    # Dropping one would both orphan history and let its index be reissued (the
    # next free index is "highest ever used + 1"), so this is a hard error: a
    # removed model must stay in catalog_data.py, renamed at most.
    for row in existing["exercises"]:
        match = next((e for e in catalog["exercises"] if e["id"] == row["id"]), None)
        assert match, f"exercise id dropped: {row['id']} ({row['name']})"
        assert match["name"] == row["name"], f"exercise id reassigned: {row['id']}"
    for row in existing["equipmentModels"]:
        match = next((m for m in catalog["equipmentModels"] if m["id"] == row["id"]), None)
        assert match, f"model id dropped: {row['id']} ({row['modelName']})"
        assert (match["manufacturer"], match["modelName"]) \
            == (row["manufacturer"], row["modelName"]), f"model id reassigned: {row['id']}"

    if catalog["version"] <= existing["version"] and catalog != existing:
        print("warning: content changed without a version bump", file=sys.stderr)


def render(catalog: dict) -> str:
    """One line per catalog row — ~2k lines instead of ~14k, and a rename or a
    new model shows up as a one-line diff."""
    def rows(key: str) -> str:
        body = ",\n".join("    " + json.dumps(row, ensure_ascii=False)
                          for row in catalog[key])
        return f'  "{key}": [\n{body}\n  ]'

    return ("{\n"
            f'  "version": {catalog["version"]},\n'
            f"{rows('exercises')},\n"
            f"{rows('equipmentModels')}\n"
            "}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="exit non-zero if the committed JSON is out of date")
    args = parser.parse_args()

    catalog = build()
    text = render(catalog)
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != text:
            print("SeedCatalog.json is stale — rerun scripts/generate_seed_catalog.py")
            return 1
        print("SeedCatalog.json is up to date")
        return 0

    OUTPUT.write_text(text)
    manufacturers = {m["manufacturer"] for m in catalog["equipmentModels"]}
    print(f"wrote {OUTPUT.relative_to(REPO)}: version {catalog['version']}, "
          f"{len(catalog['exercises'])} exercises, "
          f"{len(catalog['equipmentModels'])} models, "
          f"{len(manufacturers)} manufacturers")
    print(f"next free exercise index {len(catalog['exercises']) + 1}, "
          f"next free model index {len(catalog['equipmentModels']) + 1}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
