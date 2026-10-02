#!/usr/bin/env python3
"""Verify a copied app data container (public beta ticket 01, DEVELOPMENT → Container backup and restore).

    verify_container.py <container-dir> [--out report.json] [--expect other-report.json]

Writes a report with a SHA-256 manifest of every file, SQLite `integrity_check` for every database, and the
store's row counts (workouts, unfinished workouts, sets, templates, and every entity table). Databases are
checked on a temporary copy: opening a store in place can checkpoint its write-ahead log and change the backup.

`--expect` compares the restore set (RESTORE_SET below) against an earlier report's manifest and fails on any
missing or different file — the check that a restore copied exactly the backed-up bytes before the app launches.

Exit status: 0 when every database is `ok` (and, with --expect, the restore set matches); 1 otherwise.
"""
import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tempfile

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


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("container")
    parser.add_argument("--out")
    parser.add_argument("--expect", help="an earlier report whose restore-set files must match byte for byte")
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

    report["ok"] = ok
    if args.out:
        with open(args.out, "w") as handle:
            json.dump(report, handle, indent=2)
    summary = {k: v for k, v in report.items() if k != "manifest"}
    print(json.dumps(summary, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
