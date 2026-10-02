#!/usr/bin/env python3
"""Verify a copied app data container (public beta ticket 01, DEVELOPMENT → Container backup and restore).

    verify_container.py <container-dir> [--out report.json] [--expect other-report.json] [--export export.json]

Writes a report with a SHA-256 manifest of every file, SQLite `integrity_check` for every database, and the
store's row counts (workouts, unfinished workouts, sets, templates, and every entity table). Databases are
checked on a temporary copy: opening a store in place can checkpoint its write-ahead log and change the backup.

`--expect` compares the restore set (RESTORE_SET below) against an earlier report's manifest and fails on any
missing or different file — the check that a restore copied exactly the backed-up bytes before the app launches.

`--export` is a quick structural check against a JSON export the app wrote just before the capture (Settings →
Export → JSON, no workout in progress): every exported workout and set **ID** must be in the captured store, and
the export's counts must equal the store's rows. It compares no values: a capture that lost a committed *edit* (an
incomplete WAL copy) keeps every ID and count and passes it (Codex review 01b, R2.1). The value check is the
round trip — `simulator_export.sh` restores the capture into a disposable Simulator and the app exports it again;
`compare_exports.py` then requires that export to equal the phone's.

Exit status: 0 when every database is `ok` (and, with --expect, the restore set matches; with --export, the
capture contains the export); 1 otherwise.
"""
import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import uuid

STORE = "Library/Application Support/default.store"
DB_SUFFIXES = (".store", ".sqlite", ".db")
SIDE_FILES = ("-wal", "-shm")


def restore_set(bundle_id):
    """The files that hold the user's data and settings; caches, snapshots and saved state are rebuilt by iOS."""
    return ("Library/Application Support/", f"Library/Preferences/{bundle_id}.plist", "Documents/")


def in_restore_set(path, bundle_id):
    return any(path == p or (p.endswith("/") and path.startswith(p)) for p in restore_set(bundle_id))


def manifest(root):
    files = {}
    for dirpath, _, names in os.walk(root):
        for name in names:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            digest = hashlib.sha256()
            with open(full, "rb") as handle:
                for chunk in iter(lambda: handle.read(1 << 20), b""):
                    digest.update(chunk)
            files[rel] = {"sha256": digest.hexdigest(), "bytes": os.path.getsize(full)}
    return dict(sorted(files.items()))


def copy_database(root, rel, into):
    """Copy a database and its -wal/-shm into a scratch folder; return the copy's path."""
    target = os.path.join(into, os.path.basename(rel))
    for suffix in ("",) + SIDE_FILES:
        source = os.path.join(root, rel + suffix)
        if os.path.exists(source):
            shutil.copy2(source, target + suffix)
    return target


def entity_tables(connection):
    names = [r[0] for r in connection.execute("select name from sqlite_master where type='table'")]
    return sorted(n for n in names if n.startswith("Z") and not n.startswith("Z_"))


def check_database(root, rel):
    with tempfile.TemporaryDirectory() as scratch:
        connection = sqlite3.connect(copy_database(root, rel, scratch))
        try:
            result = {"path": rel, "integrity": [r[0] for r in connection.execute("pragma integrity_check")]}
            if rel == STORE:
                result["workouts"] = connection.execute("select count(*) from ZWORKOUT").fetchone()[0]
                result["unfinished"] = connection.execute(
                    "select count(*) from ZWORKOUT where ZFINISHEDAT is null").fetchone()[0]
                result["sets"] = connection.execute("select count(*) from ZSETRECORD").fetchone()[0]
                result["templates"] = connection.execute("select count(*) from ZWORKOUTTEMPLATE").fetchone()[0]
                result["rows"] = {t: connection.execute(f'select count(*) from "{t}"').fetchone()[0]
                                  for t in entity_tables(connection)}
        finally:
            connection.close()
    return result


EXPORT_COUNTS = {"workouts": "ZWORKOUT", "entries": "ZEXERCISEENTRY", "sets": "ZSETRECORD", "gyms": "ZGYM",
                 "machines": "ZMACHINEINSTANCE", "templates": "ZWORKOUTTEMPLATE", "presets": "ZEXERCISEPRESET",
                 "cardioSegments": "ZCARDIOSEGMENT"}


def check_export(root, export_path):
    """Compare the capture with a JSON export (ExportSnapshot): IDs present, counts equal."""
    with open(export_path) as handle:
        snapshot = json.load(handle)
    exported_workouts = {w["id"].upper() for w in snapshot["workouts"]}
    exported_sets = {s["id"].upper() for w in snapshot["workouts"] for e in w["entries"] for s in e["sets"]}
    with tempfile.TemporaryDirectory() as scratch:
        connection = sqlite3.connect(copy_database(root, STORE, scratch))
        try:
            def ids(table):
                return {str(uuid.UUID(bytes=r[0])).upper() for r in connection.execute(f"select ZID from {table}")}
            stored_workouts, stored_sets = ids("ZWORKOUT"), ids("ZSETRECORD")
            rows = {t: connection.execute(f"select count(*) from {t}").fetchone()[0] for t in EXPORT_COUNTS.values()}
        finally:
            connection.close()
    count_mismatches = {k: [snapshot["counts"][k], rows[t]] for k, t in EXPORT_COUNTS.items()
                        if snapshot["counts"].get(k) is not None and snapshot["counts"][k] != rows[t]}
    result = {"export": os.path.abspath(export_path), "exportedAt": snapshot.get("exportedAt"),
              "workouts_missing_from_capture": sorted(exported_workouts - stored_workouts),
              "sets_missing_from_capture": sorted(exported_sets - stored_sets),
              "count_mismatches_export_vs_capture": count_mismatches}
    result["ok"] = not (result["workouts_missing_from_capture"] or result["sets_missing_from_capture"]
                        or count_mismatches)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("container")
    parser.add_argument("--out")
    parser.add_argument("--expect", help="an earlier report whose restore-set files must match byte for byte")
    parser.add_argument("--export", help="a JSON export taken just before the capture; the capture must contain it")
    parser.add_argument("--bundle-id", default="com.ericlee4992.workouttracker")
    args = parser.parse_args()

    files = manifest(args.container)
    databases = [check_database(args.container, rel) for rel in files if rel.endswith(DB_SUFFIXES)]
    report = {"container": os.path.abspath(args.container), "files": len(files),
              "bytes": sum(f["bytes"] for f in files.values()), "databases": databases, "manifest": files}
    ok = bool(databases) and all(d["integrity"] == ["ok"] for d in databases)
    if not any(d["path"] == STORE for d in databases):
        ok = False
        report["error"] = f"no {STORE}"

    if args.expect:
        with open(args.expect) as handle:
            expected = {k: v for k, v in json.load(handle)["manifest"].items() if in_restore_set(k, args.bundle_id)}
        actual = {k: v for k, v in files.items() if in_restore_set(k, args.bundle_id)}
        mismatches = sorted(k for k in expected if actual.get(k, {}).get("sha256") != expected[k]["sha256"])
        extra = sorted(set(actual) - set(expected))
        report["restore_set_check"] = {"expected": len(expected), "mismatched_or_missing": mismatches,
                                       "unexpected": extra}
        ok = ok and not mismatches and not extra

    if args.export:
        try:
            report["export_check"] = check_export(args.container, args.export)
        except (sqlite3.Error, OSError, KeyError, ValueError) as error:
            report["export_check"] = {"ok": False, "error": f"{type(error).__name__}: {error}"}
        ok = ok and report["export_check"]["ok"]

    report["ok"] = ok
    if args.out:
        with open(args.out, "w") as handle:
            json.dump(report, handle, indent=2)
    summary = {k: v for k, v in report.items() if k != "manifest"}
    print(json.dumps(summary, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
