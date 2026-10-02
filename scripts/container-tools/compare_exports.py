#!/usr/bin/env python3
"""Semantic comparison of two JSON exports of the app (public beta ticket 01).

    compare_exports.py <phone-export.json> <round-trip-export.json> [--out report.json]

The phone export is taken just before a container capture; the round-trip export is what the app exports after
that capture is restored into a disposable Simulator (`simulator_export.sh`). Equal exports mean the capture
holds the same history the phone showed: every exported workout, entry, set, template, gym, machine, exercise,
model, memory, override and preference **value**, not only IDs and counts.

Normalization, and nothing else: `exportedAt` is ignored (it is the export's own clock); timestamps are compared
as instants (the export writes local time with an offset, and the two devices' time zones may differ). Floats are
compared exactly — the same code wrote both files. `appVersion` and `schemaVersion` must match: a different build
could export differently, and that must be judged by a person, not normalized away.

Outside export coverage (judge separately): rows the export omits by design (unreferenced seeded catalog rows),
persistent-history tables, and non-store files — `compare_stores.py` and `verify_container.py` cover those.

Exit status: 0 when the exports are equal under these rules; 1 otherwise (differences listed by JSON path).
"""
import argparse
import datetime
import json
import re
import sys

IGNORED_TOP_LEVEL = {"exportedAt"}
TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$")


def normalize(value):
    if isinstance(value, str) and TIMESTAMP.match(value):
        instant = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return ("instant", instant.astimezone(datetime.timezone.utc).isoformat())
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items()}
    if isinstance(value, list):
        return [normalize(v) for v in value]
    return value


def differences(a, b, path="$", out=None, limit=200):
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if isinstance(a, dict) and isinstance(b, dict):
        for key in sorted(set(a) | set(b)):
            if key not in a or key not in b:
                out.append({"path": f"{path}.{key}", "phone": a.get(key, "<absent>"),
                            "round_trip": b.get(key, "<absent>")})
            else:
                differences(a[key], b[key], f"{path}.{key}", out, limit)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append({"path": f"{path}.length", "phone": len(a), "round_trip": len(b)})
        for index, (x, y) in enumerate(zip(a, b)):
            label = x.get("id", index) if isinstance(x, dict) else index
            differences(x, y, f"{path}[{label}]", out, limit)
    elif a != b or type(a) is not type(b):
        out.append({"path": path, "phone": a, "round_trip": b})
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("phone_export")
    parser.add_argument("round_trip_export")
    parser.add_argument("--out")
    args = parser.parse_args()
    with open(args.phone_export) as a, open(args.round_trip_export) as b:
        phone, round_trip = json.load(a), json.load(b)
    phone = {k: v for k, v in phone.items() if k not in IGNORED_TOP_LEVEL}
    round_trip = {k: v for k, v in round_trip.items() if k not in IGNORED_TOP_LEVEL}
    diffs = differences(normalize(phone), normalize(round_trip))
    report = {"equal": not diffs, "differences": diffs, "counts": phone.get("counts")}
    if args.out:
        with open(args.out, "w") as handle:
            json.dump(report, handle, indent=2, default=str)
    print(json.dumps(report, indent=2, default=str))
    return 0 if not diffs else 1


if __name__ == "__main__":
    sys.exit(main())
