#!/usr/bin/env python3
"""Row-by-row preservation check between two copies of the app's store (public beta ticket 01).

    compare_stores.py <old-container-dir> <new-container-dir> [--out report.json]

Compares every entity table (Z* except Z_* bookkeeping) of `Library/Application Support/default.store` in the
old copy with the new copy, matching rows by Z_PK. `Z_OPT` (SwiftData's optimistic-lock counter) is ignored, and
`Z_ENT` is compared by entity *name* through each store's Z_PRIMARYKEY, so a renumbered entity is not reported
as changed data. Persistent-history tables (A*) are not compared: iOS appends to them on every launch.

Reports, per table: rows missing from the new copy, rows whose values changed (with the columns), rows added,
and columns removed or added. Both stores are opened on temporary copies.

Exit status: 0 when every old row is present and unchanged and no table or column disappeared; 1 otherwise.
New rows or columns alone do not fail the check, but they are listed for a person to judge.
"""
import argparse
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verify_container import STORE, copy_database, entity_tables  # noqa: E402

import sqlite3  # noqa: E402

IGNORED_COLUMNS = {"Z_OPT"}


def show(value):
    if isinstance(value, bytes):
        return f"<{len(value)} bytes>"
    text = repr(value)
    return text if len(text) <= 80 else text[:77] + "..."


def load(container, scratch):
    connection = sqlite3.connect(copy_database(container, STORE, scratch))
    entities = dict(connection.execute("select Z_ENT, Z_NAME from Z_PRIMARYKEY"))
    tables = {}
    for table in entity_tables(connection):
        cursor = connection.execute(f'select * from "{table}"')
        columns = [d[0] for d in cursor.description]
        rows = {}
        for row in cursor:
            values = dict(zip(columns, row))
            if "Z_ENT" in values:
                values["Z_ENT"] = entities.get(values["Z_ENT"], values["Z_ENT"])
            rows[values["Z_PK"]] = values
        tables[table] = {"columns": columns, "rows": rows}
    connection.close()
    return tables


def compare(old, new):
    report = {"missing_tables": sorted(set(old) - set(new)), "new_tables": sorted(set(new) - set(old)),
              "tables": {}}
    preserved = not report["missing_tables"]
    for table in sorted(set(old) & set(new)):
        old_rows, new_rows = old[table]["rows"], new[table]["rows"]
        removed_columns = sorted(set(old[table]["columns"]) - set(new[table]["columns"]))
        compared = [c for c in old[table]["columns"] if c not in IGNORED_COLUMNS and c not in removed_columns]
        changed = {}
        for pk, row in old_rows.items():
            if pk not in new_rows:
                continue
            diffs = {c: [show(row[c]), show(new_rows[pk][c])] for c in compared if row[c] != new_rows[pk][c]}
            if diffs:
                changed[pk] = diffs
        missing = sorted(set(old_rows) - set(new_rows))
        entry = {"old_rows": len(old_rows), "new_rows": len(new_rows), "missing_rows": missing,
                 "changed_rows": changed, "added_rows": sorted(set(new_rows) - set(old_rows)),
                 "removed_columns": removed_columns,
                 "added_columns": sorted(set(new[table]["columns"]) - set(old[table]["columns"]))}
        report["tables"][table] = entry
        preserved = preserved and not missing and not changed and not removed_columns
    report["every_old_row_preserved"] = preserved
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("old")
    parser.add_argument("new")
    parser.add_argument("--out")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
        report = compare(load(args.old, a), load(args.new, b))
    if args.out:
        with open(args.out, "w") as handle:
            json.dump(report, handle, indent=2)
    noteworthy = {t: e for t, e in report["tables"].items()
                  if e["missing_rows"] or e["changed_rows"] or e["added_rows"] or e["removed_columns"]
                  or e["added_columns"]}
    print(json.dumps({"tables_compared": len(report["tables"]), "missing_tables": report["missing_tables"],
                      "new_tables": report["new_tables"], "differences": noteworthy,
                      "every_old_row_preserved": report["every_old_row_preserved"]}, indent=2))
    return 0 if report["every_old_row_preserved"] else 1


if __name__ == "__main__":
    sys.exit(main())
