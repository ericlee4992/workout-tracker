#!/bin/bash
# Public beta ticket 08: checks a D1 export (`wrangler d1 export stacked --remote`) — restores it into a throwaway
# SQLite file, then compares every table's row count with production and runs SQLite's integrity and foreign-key
# checks. Read-only on production. Run from server/:
#
#   scripts/check-export.sh ~/WorkoutTracker-Backups/server/<date>-<reason>/stacked.sql
set -euo pipefail
[ -f "${1:-}" ] || { echo "usage: scripts/check-export.sh <export.sql>" >&2; exit 2; }
work=$(mktemp -d); db="$work/restore.db"
trap 'rm -rf "$work"' EXIT
sqlite3 "$db" < "$1"
tables=$(sqlite3 "$db" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' ORDER BY name")
# D1 caps compound SELECTs, so one row of scalar subqueries instead of a UNION.
sql="SELECT "; for t in $tables; do sql+="(SELECT count(*) FROM $t) AS $t, "; done; sql=${sql%, }
rows='Object.entries(JSON.parse(require("fs").readFileSync(0,"utf8"))'
sqlite3 -json "$db" "$sql" | node -e "$rows[0]).forEach(([t,n])=>console.log(t+' '+n))" | sort > "$work/export"
npx wrangler d1 execute stacked --remote --json --command "$sql" 2>/dev/null \
  | node -e "$rows[0].results[0]).forEach(([t,n])=>console.log(t+' '+n))" | sort > "$work/production"
echo "table export production"; join "$work/export" "$work/production"
check=$(sqlite3 "$db" "PRAGMA foreign_key_check; PRAGMA integrity_check;")
if [ -s "$work/export" ] && cmp -s "$work/export" "$work/production" && [ "$check" = "ok" ]; then
  echo "OK: restores cleanly; every table's row count matches production."
else
  echo "MISMATCH or damage (integrity: $check). Rows written since the export also differ — re-export and re-check." >&2
  exit 1
fi
