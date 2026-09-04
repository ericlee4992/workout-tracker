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

A rename therefore has to be declared: the stable key changes, so RENAMED_MODELS
below re-points the old key's id at the new name. A rename that *merges* two rows
describing one real machine also retires the loser's id (see RENAMED_MODELS).

## Identity duplicates

Two catalog rows for one real machine are worse than a missing row: D23 keys
history, records and the same-model-elsewhere layer on the model UUID, so a user
who picks one today and the other tomorrow silently splits their own history.
`verify()` rejects near-duplicate identities, not just byte-identical names —
within a manufacturer, rows whose names agree once line words and model codes are
removed. Anything flagged must either be merged or listed, with a reason, in
ADJUDICATED_DISTINCT.
"""

from __future__ import annotations

import argparse
import itertools
import json
import re

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from catalog_data import (  # noqa: E402
    EQUIPMENT_TYPES, MANUFACTURERS, TYPE_MARKER,
)

REPO = Path(__file__).resolve().parent.parent
OUTPUT = REPO / "WorkoutTracker" / "Resources" / "SeedCatalog.json"

# 3 (ticket 21): every model gained an `equipmentType`. The bump is what makes
# the reconciler rewrite already-seeded rows — without it, stores seeded at
# version 2 would keep a nil type on all 1887 models (D24).
# 4 (codex-review-4): ten duplicate identities merged onto their older id, the
# survivors renamed to the researched name, and the bodyweight ab/back benches
# relinked off the weighted machine exercises.
# 5 (milestone 9, ticket 04): fourteen dumbbell movements as exercises of their
# own. Until now the catalog had ONE dumbbell exercise, so a dumbbell bench was
# logged as "Bench Press" with the Dumbbell tag; the user asked for separate
# exercises. The bump also triggers a one-time move of dumbbell-tagged history
# onto the new rows (Domain/DumbbellHistoryMove.swift).
CATALOG_VERSION = 5

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
    # -- new in version 4 (codex-review-4) ----------------------------------
    # An ab bench and a hyperextension bench are bodyweight apparatus. Linking
    # them to the *weighted* machine exercises above computed their records
    # under the wrong load-type rules (D20): weight×reps and a Brzycki e1RM for
    # a movement that has no external load unless you hold a plate.
    ("benchCrunch", "Bench Crunch", "bodyweightPlus", [BW], "Core"),
    ("hyperextension", "Hyperextension", "bodyweightPlus", [BW], "Back"),
    # -- new in version 5 (milestone 9, ticket 04): dumbbell movements --------
    # Named "Dumbbell X" so they sort and search together, and so the barbell/
    # machine row of the same movement keeps its established name.
    ("dbBenchPress", "Dumbbell Bench Press", "weighted", [DB], "Chest"),
    ("dbInclinePress", "Dumbbell Incline Press", "weighted", [DB], "Chest"),
    ("dbDeclinePress", "Dumbbell Decline Press", "weighted", [DB], "Chest"),
    ("dbFly", "Dumbbell Fly", "weighted", [DB], "Chest"),
    ("dbFloorPress", "Dumbbell Floor Press", "weighted", [DB], "Chest"),
    ("dbShoulderPress", "Dumbbell Shoulder Press", "weighted", [DB], "Shoulders"),
    ("dbLateralRaise", "Dumbbell Lateral Raise", "weighted", [DB], "Shoulders"),
    ("dbRow", "Dumbbell Row", "weighted", [DB], "Back"),
    ("dbShrug", "Dumbbell Shrug", "weighted", [DB], "Back"),
    ("dbRomanianDeadlift", "Dumbbell Romanian Deadlift", "weighted", [DB], "Hamstrings"),
    ("dbLunge", "Dumbbell Lunge", "weighted", [DB], "Quads"),
    ("bulgarianSplitSquat", "Bulgarian Split Squat", "weighted", [DB], "Quads"),
    ("dbGobletSquat", "Dumbbell Goblet Squat", "weighted", [DB], "Quads"),
    ("dbHipThrust", "Dumbbell Hip Thrust", "weighted", [DB], "Glutes"),
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

# ---------------------------------------------------------------------------
# Declared renames and identity merges (version 4, codex-review-4)
#
# (manufacturer, name in the previously committed JSON, name now, the model
#  index that keeps its UUID, the index of a duplicate row this retires or None)
#
# Every merge below was confirmed against docs/catalog-sources/: the version-1
# row and the researched row name the same real machine, and the manufacturer's
# line contains exactly one such machine. The *older* id always survives —
# it is the one a version-1 install has already logged against — and takes the
# researched name (`name` is an allowlisted mutable seeded field, D24).
# ---------------------------------------------------------------------------

RENAMED_MODELS = [
    # -- pure renames: the researched name for a row that had no duplicate ---
    ("Life Fitness", "Signature Series Lat Pulldown",
     "Signature Series Pulldown", 3, None),
    ("Life Fitness", "Signature Series Cable Motion Dual Adjustable Pulley",
     "Signature Series Dual Adjustable Pulley", 4, None),
    ("Hoist", "Mi7 Functional Trainer",
     "Mi7 Functional Training System Mi-7-MB", 24, None),
    # Precor lists a Glutebuilder plate-loaded *and* a selectorized machine
    # under one name; only the selectorized one carried its code, so the two
    # were indistinguishable in the picker. Not duplicates — disambiguated.
    ("Precor", "Glutebuilder Hip Thrust Elite",
     "Glutebuilder Plate Loaded Hip Thrust Elite", 269, None),
    ("Precor", "Glutebuilder Pendulum Kickback",
     "Glutebuilder Plate Loaded Pendulum Kickback", 276, None),
    ("Precor", "Glutebuilder Kneeling Glute Isolator",
     "Glutebuilder Plate Loaded Kneeling Glute Isolator", 277, None),
    # -- identity merges: one machine, two rows ------------------------------
    ("Hammer Strength", "Select Leg Press",
     "Select Seated Leg Press", 7, 169),
    ("Precor", "Vitality Series Seated Row",
     "Vitality Seated Row (VSL019BP)", 11, 239),
    ("Precor", "Resolute Series Leg Press",
     "Resolute Leg Press (RSL0602)", 12, 225),
    ("Precor", "Discovery Series Shoulder Press",
     "Discovery Plate Loaded Shoulder Press (DPL0550)", 13, 255),
    ("Matrix", "Versa Series Chest Press",
     "VS-S13 Converging Chest Press", 18, 651),
    ("Matrix", "Aura Series Seated Row", "G3-S31 Seated Row", 19, 634),
    ("Matrix", "Magnum Smith Machine", "MG-PL62 Smith Machine", 20, 697),
    ("Nautilus", "Impact Strength Shoulder Press", "Impact Shoulder Press", 21, 376),
    ("Nautilus", "Impact Strength Leg Press", "Impact Seated Leg Press", 22, 389),
    ("Hoist", "ROC-IT Lat Pulldown", "Lat Pulldown RS-2201", 23, 1404),
]

# Ids that named a duplicate row and are now retired. They are never reissued
# (they stay in the index space) and must never reappear in the catalog.
RETIRED_MODEL_IDS = {MODEL_NS.format(retired)
                     for *_rest, retired in RENAMED_MODELS if retired is not None}


def apply_renames(model_ids: dict) -> None:
    """Re-points the sticky id lookup at the declared new names.

    Idempotent: after the JSON has been regenerated the old key is gone and the
    new one already holds the surviving id, which is then only re-asserted.
    """
    for manufacturer, old_name, new_name, index, retired in RENAMED_MODELS:
        survivor = MODEL_NS.format(index)
        previous = model_ids.pop((manufacturer, old_name), None)
        assert previous in (survivor, None), \
            f"{manufacturer} / {old_name}: expected {survivor}, found {previous}"
        held = model_ids.get((manufacturer, new_name))
        if retired is None:
            assert held in (survivor, None), \
                f"{manufacturer} / {new_name}: rename would collide with {held}"
        else:
            assert held in (MODEL_NS.format(retired), survivor), \
                f"{manufacturer} / {new_name}: expected the merged-away " \
                f"{MODEL_NS.format(retired)}, found {held}"
        model_ids[(manufacturer, new_name)] = survivor


def load_existing() -> dict:
    if not OUTPUT.exists():
        return {"version": 0, "exercises": [], "equipmentModels": []}
    return json.loads(OUTPUT.read_text())


def build() -> dict:
    existing = load_existing()
    exercise_ids = {e["name"]: e["id"] for e in existing["exercises"]}
    model_ids = {(m["manufacturer"], m["modelName"]): m["id"]
                 for m in existing["equipmentModels"]}
    apply_renames(model_ids)

    def next_index(ids: dict, namespace: str) -> int:
        used = [int(value.rsplit("-", 1)[1]) for value in ids.values()]
        if namespace == MODEL_NS:
            # A retired index is spent forever: reissuing it would hand a new
            # machine the UUID a merged-away duplicate was logged against.
            used += [int(uuid.rsplit("-", 1)[1]) for uuid in RETIRED_MODEL_IDS]
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
        # Ticket 21: `TYPE(...)` markers set the equipment type for the entries
        # that follow; a three-element entry overrides it for itself. Both may
        # be None — "the research did not establish it" is a real answer, and
        # the app files those models under "Uncategorized".
        section_type = None
        for entry in entries:
            if entry[0] == TYPE_MARKER:
                section_type = entry[1]
                assert section_type is None or section_type in EQUIPMENT_TYPES, \
                    f"{manufacturer}: unknown equipment type {section_type}"
                continue
            model_name, links = entry[0], entry[1]
            equipment_type = entry[2] if len(entry) > 2 else section_type
            assert equipment_type is None or equipment_type in EQUIPMENT_TYPES, \
                f"{manufacturer} {model_name}: unknown equipment type {equipment_type}"
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
                "equipmentType": equipment_type,
                "exerciseIDs": ids,
            })

    catalog = {"version": CATALOG_VERSION, "exercises": exercises, "equipmentModels": models}
    verify(catalog, existing)
    return catalog


# ---------------------------------------------------------------------------
# Near-duplicate identity detection
#
# A manufacturer's own model code is an identity: two rows carrying different
# codes are different products however alike their names read. So a pair is only
# suspect when at least one side carries no code (the under-specified form that
# produced every duplicate found in the version-2/3 catalog), or when both carry
# the same code.
# ---------------------------------------------------------------------------

# Words that name a *line*, never a machine, and are written inconsistently
# across sources ("Impact Strength Shoulder Press" vs "Impact Shoulder Press").
IDENTITY_NOISE = {"series", "line", "strength", "the"}

# Tokens whose presence alone rarely distinguishes two machines in one line.
# A pair differing by exactly one of these is suspect, not condemned.
# "plateloaded" is here rather than in the noise set because a manufacturer that
# sells the *same* movement both plate-loaded and selectorized (Precor
# Glutebuilder, PRIME PRODIGY) really does have two machines — but a row that
# just omits the words is usually the same machine written twice.
IDENTITY_WEAK = {"seated", "standing", "converging", "diverging", "vertical",
                 "angled", "plateloaded"}

# Matrix writes its lines as a code prefix; the research confirmed the mapping,
# so "Aura Series Seated Row" and "G3-S31 Seated Row" are comparable.
MATRIX_LINES = {"g3": "aura", "g7": "ultra", "vs": "versa", "mg": "magnum",
                "go": "go", "vy": "varsity", "g1": "varsity"}

# Pairs the near-duplicate rule flags that are genuinely different machines,
# each checked against docs/catalog-sources/. Adding a row that trips the rule
# means deciding: merge it, or justify it here.
ADJUDICATED_DISTINCT = [
    # Precor sells the same Glutebuilder movement plate-loaded *and*
    # selectorized; the plate-loaded rows were renamed to say so (RENAMED_MODELS).
    ("Precor", "Glutebuilder Plate Loaded Hip Thrust Elite",
     "Glutebuilder Hip Thrust Elite (GSL0612)",
     "Precor lists a plate-loaded and a selectorized Hip Thrust Elite"),
    ("Precor", "Glutebuilder Plate Loaded Pendulum Kickback",
     "Glutebuilder Pendulum Kickback (GSL0617)",
     "Precor lists a plate-loaded and a selectorized Pendulum Kickback"),
    ("Precor", "Glutebuilder Plate Loaded Kneeling Glute Isolator",
     "Glutebuilder Kneeling Glute Isolator (GSL0360)",
     "Precor lists a plate-loaded and a selectorized Kneeling Glute Isolator"),
    ("Hammer Strength", "Select Leg Curl", "Select Seated Leg Curl",
     "prone and seated leg curl are separate Select machines"),
    ("Life Fitness", "Insignia Series Leg Curl", "Insignia Series Seated Leg Curl",
     "prone and seated leg curl are separate Insignia machines"),
    ("Life Fitness", "Axiom Series Leg Extension / Leg Curl",
     "Axiom Series Seated Leg Curl / Extension",
     "two different Axiom dual stations, both listed"),
    ("Nautilus", "Impact Leg Curl", "Impact Seated Leg Curl",
     "prone and seated leg curl are separate Impact machines"),
    ("Technogym", "Pure Strength Calf", "Pure Strength Seated Calf",
     "standing and seated calf are separate Pure Strength machines"),
    ("Watson", "PL Chest Press", "PL Standing Chest Press",
     "Watson lists both a seated and a standing plate-loaded chest press"),
    ("Watson", "PL 45° Leg Press", "PL Vertical Leg Press",
     "45° and vertical leg press are separate Watson machines"),
    ("Watson", "PL 45º Calf Raise", "PL Seated Calf Raise",
     "45° and seated calf raise are separate Watson machines"),
    ("Watson", "PL Animal Leg Press", "PL Animal Vertical Leg Press",
     "the Animal range lists both"),
    ("Watson", "SS Hip Abductor", "SS Standing Hip Abductor",
     "seated and standing abductor are separate Watson machines"),
]


def identity_tokens(manufacturer: str, model_name: str):
    """(model codes, identity words) for one row."""
    codes, words = [], []
    model_name = re.sub(r"plate[\s-]?loaded", "plateloaded", model_name,
                        flags=re.IGNORECASE)
    for raw in re.split(r"[\s/(),|·]+", model_name):
        raw = raw.strip("-–.:")
        if not raw:
            continue
        token = raw.lower()
        head = token.split("-")[0]
        if manufacturer == "Matrix" and head in MATRIX_LINES and "-" in token:
            words.append(MATRIX_LINES[head])
            codes.append(token)
        elif any(character.isdigit() for character in token):
            codes.append(token)
        else:
            words.extend(w for w in token.split("-")
                         if w and w not in IDENTITY_NOISE)
    return frozenset(codes), frozenset(words)


def near_duplicate_identities(models: list) -> list:
    """Pairs of rows that look like one real machine written two ways."""
    by_manufacturer: dict[str, list] = {}
    for model in models:
        codes, words = identity_tokens(model["manufacturer"], model["modelName"])
        by_manufacturer.setdefault(model["manufacturer"], []).append(
            (model, codes, words))

    found = []
    for manufacturer, rows in by_manufacturer.items():
        for (a, codes_a, words_a), (b, codes_b, words_b) in \
                itertools.combinations(rows, 2):
            comparable = (codes_a and codes_a == codes_b) or not codes_a or not codes_b
            if not comparable:
                continue
            difference = words_a ^ words_b
            if difference and not (len(difference) == 1 and difference <= IDENTITY_WEAK):
                continue
            reason = ("identical identity" if not difference
                      else f"differ only by {next(iter(difference))!r}")
            found.append((manufacturer, a["modelName"], b["modelName"], reason))
    return found


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
    # removed model must stay in catalog_data.py, renamed at most — or be
    # declared in RENAMED_MODELS, which is the only way an id is retired.
    renamed = {(manufacturer, old): new
               for manufacturer, old, new, *_rest in RENAMED_MODELS}
    for row in existing["exercises"]:
        match = next((e for e in catalog["exercises"] if e["id"] == row["id"]), None)
        assert match, f"exercise id dropped: {row['id']} ({row['name']})"
        assert match["name"] == row["name"], f"exercise id reassigned: {row['id']}"
    for row in existing["equipmentModels"]:
        match = next((m for m in catalog["equipmentModels"] if m["id"] == row["id"]), None)
        if row["id"] in RETIRED_MODEL_IDS:
            assert match is None, \
                f"retired model id reappeared: {row['id']} ({row['modelName']})"
            continue
        assert match, f"model id dropped: {row['id']} ({row['modelName']})"
        expected = renamed.get((row["manufacturer"], row["modelName"]),
                               row["modelName"])
        assert (match["manufacturer"], match["modelName"]) \
            == (row["manufacturer"], expected), f"model id reassigned: {row['id']}"
    assert not (RETIRED_MODEL_IDS & set(model_ids)), "retired model id reissued"

    # Near-duplicate identities (D23): one machine must not have two UUIDs.
    allowed = {frozenset((manufacturer, a, b))
               for manufacturer, a, b, _reason in ADJUDICATED_DISTINCT}
    unresolved = [row for row in near_duplicate_identities(catalog["equipmentModels"])
                  if frozenset(row[:3]) not in allowed]
    assert not unresolved, (
        "near-duplicate catalog identities — merge them (RENAMED_MODELS) or "
        "record why they differ (ADJUDICATED_DISTINCT):\n"
        + "\n".join(f"  {m}: {a!r} vs {b!r} ({why})" for m, a, b, why in unresolved))
    stale = [pair for pair in ADJUDICATED_DISTINCT
             if frozenset(pair[:3]) not in
             {frozenset(row[:3]) for row in
              near_duplicate_identities(catalog["equipmentModels"])}]
    assert not stale, f"ADJUDICATED_DISTINCT entries no longer apply: {stale}"

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
    # Not "count + 1": retired indices (RENAMED_MODELS) are spent but unused.
    def next_free(rows: list, key: str) -> int:
        used = {int(row["id"].rsplit("-", 1)[1]) for row in rows}
        if key == "equipmentModels":
            used |= {int(uuid.rsplit("-", 1)[1]) for uuid in RETIRED_MODEL_IDS}
        return max(used, default=0) + 1

    print(f"next free exercise index {next_free(catalog['exercises'], 'exercises')}, "
          f"next free model index "
          f"{next_free(catalog['equipmentModels'], 'equipmentModels')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
