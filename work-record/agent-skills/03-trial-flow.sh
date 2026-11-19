#!/bin/bash
# Pass 2 of agent-skills 03's trial: the whole My settings flow, unattended.
set -u
cd /Users/ericlee06/.paseo/worktrees/1qmeipq9/machine-settings
D=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B; S=scripts/sim-ui.sh; fails=0
snap(){ $S ui-automation snapshot-ui --simulator-id $D > /tmp/s.txt 2>&1; }
ref(){ grep -E "$1" /tmp/s.txt | grep -E "\|$2\|" | head -1 | cut -d'|' -f1 | tr -d ' '; }
act(){ local out; out=$("$@" 2>&1); echo "$out" | grep -q "✅" || { echo "FAIL: $*"; echo "$out" | grep -E "❌|Code" | head -2; fails=$((fails+1)); }; }
tap(){ [ -n "$1" ] || { echo "FAIL: no ref ($2)"; fails=$((fails+1)); return; }; act $S ui-automation tap --simulator-id $D --element-ref "$1"; }
scroll_to(){ for i in 1 2 3 4 5 6; do snap; r=$(ref "$1" tap); [ -n "$r" ] && return; sc=$(sed -n '/^Scroll/,/^$/p' /tmp/s.txt | grep "|swipe|" | head -1 | cut -d'|' -f1 | tr -d ' '); act $S ui-automation swipe --simulator-id $D --within-element-ref $sc --direction up; done; }
step(){ echo "[$(( $(date +%s)-T0 ))s] $1"; }
xcrun simctl terminate $D com.example.workouttracker 2>/dev/null
xcrun simctl launch $D com.example.workouttracker -uiTestReset -uiTestDesignSample -uiTestDesignLive -uiTestDesignGyms -uiTestDesignMySettings >/dev/null
sleep 6; T0=$(date +%s)
step "1 card line → edit → Save"; snap; tap "$(ref mySettings.cardLine tap)" cardLine; snap
act $S ui-automation type-text --simulator-id $D --element-ref "$(ref mySettings.field typeText)" --text "Seat 6, pins at 3" --replace-existing
snap; tap "$(ref mySettings.save tap)" save; snap
grep -q "Seat 6, pins at 3|mySettings.cardLine" /tmp/s.txt && echo "  ok: line shows the new note" || { echo "  FAIL: line not updated"; fails=$((fails+1)); }
step "2 ⋯ → My Settings… → Cancel"; tap "$(grep 'Exercise options' /tmp/s.txt | head -1 | cut -d'|' -f1 | tr -d ' ')" options; snap; tap "$(ref mySettings.menuItem tap)" menuItem; snap
grep -q "Seat 6, pins at 3|mySettings.field" /tmp/s.txt && echo "  ok: editor shows the note" || { echo "  FAIL: editor"; fails=$((fails+1)); }
tap "$(ref mySettings.cancel tap)" cancel
step "3 scroll to the chip → editor → Cancel"; scroll_to mySettings.addChip; tap "$(ref mySettings.addChip tap)" chip; snap; tap "$(ref mySettings.cancel tap)" cancel
step "4 minimise → Train → Gyms → Iron Temple → Cable Station"; snap; tap "$(ref minimizeWorkout tap)" minimize; snap; tap "$(ref '\|tab\|Train\|' tap)" train; snap
tap "$(grep -E '\|Gyms\|' /tmp/s.txt | grep '|tap|' | head -1 | cut -d'|' -f1 | tr -d ' ')" gyms; snap; tap "$(ref 'gymRow.Iron Temple' tap)" iron; snap
tap "$(ref 'machineRow.Cable Station' tap)" cable; scroll_to "mySettings.machineRow.Low Row"
grep -q "mySettings.machineRow.Low Row" /tmp/s.txt && echo "  ok: Low Row row" || { echo "  FAIL: Low Row row"; fails=$((fails+1)); }
step "done"; echo "failures: $fails"
