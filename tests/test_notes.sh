#!/usr/bin/env bash
set -euo pipefail

TMP_DB="$(mktemp)"
export NOTES_DB_PATH="$TMP_DB"

./notes.sh topic add "Team" >/dev/null
./notes.sh meeting add "Team" "Weekly" --date 2026-02-24 >/dev/null
./notes.sh note add "Team" "Notiz" --meeting "Weekly" --body "Inhalt" >/dev/null
./notes.sh todo add "Team" "Task" --body "Erledigen" >/dev/null

./notes.sh todo list "Team" | grep -q "Task"
TODO_ID="$(./notes.sh todo list "Team" | awk '/Task/ {print $1}' | head -n1)"
./notes.sh todo done "$TODO_ID" >/dev/null
./notes.sh todo list "Team" | grep -q "DONE"

rm -f "$TMP_DB"
