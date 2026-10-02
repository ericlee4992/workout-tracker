#!/usr/bin/env python3
"""Exact comparison of two directory trees (public beta ticket 01 — the phone copy preflight).

    compare_trees.py <expected-dir> <actual-dir> [--within <relative path>]

Every file under <expected-dir> (or under its <relative path>) must exist at the same relative path under
<actual-dir> with the same SHA-256, and <actual-dir> must have no extra files there. Use it to prove that a
`devicectl device copy to` followed by `copy from` returns a probe tree (a file and a nested directory) at the
paths you expected; the restore-set filter of verify_container.py does not cover `tmp/` and must not be used for
this.

Exit status: 0 when the trees match exactly; 1 otherwise.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verify_container import manifest  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("expected")
    parser.add_argument("actual")
    parser.add_argument("--within", default="")
    args = parser.parse_args()
    expected_root = os.path.join(args.expected, args.within)
    actual_root = os.path.join(args.actual, args.within)
    if not os.path.isdir(expected_root) or not os.path.isdir(actual_root):
        print(json.dumps({"ok": False, "error": "missing directory",
                          "expected_exists": os.path.isdir(expected_root),
                          "actual_exists": os.path.isdir(actual_root)}, indent=2))
        return 1
    expected, actual = manifest(expected_root), manifest(actual_root)
    report = {"files_expected": len(expected), "files_actual": len(actual),
              "missing": sorted(set(expected) - set(actual)), "extra": sorted(set(actual) - set(expected)),
              "different": sorted(k for k in set(expected) & set(actual)
                                  if expected[k]["sha256"] != actual[k]["sha256"])}
    report["ok"] = bool(expected) and not (report["missing"] or report["extra"] or report["different"])
    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
