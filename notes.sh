#!/usr/bin/env bash
set -euo pipefail

DB_PATH="${NOTES_DB_PATH:-$HOME/.notes_app.db}"

init_db() {
  sqlite3 "$DB_PATH" <<'SQL'
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS topics (
  id INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS meetings (
  id INTEGER PRIMARY KEY,
  topic_id INTEGER NOT NULL,
  title TEXT NOT NULL,
  happened_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(topic_id, title),
  FOREIGN KEY(topic_id) REFERENCES topics(id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS entries (
  id INTEGER PRIMARY KEY,
  topic_id INTEGER NOT NULL,
  meeting_id INTEGER,
  type TEXT NOT NULL CHECK(type IN ('NOTE', 'TODO')),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN', 'DONE')),
  created_at TEXT NOT NULL,
  FOREIGN KEY(topic_id) REFERENCES topics(id) ON DELETE CASCADE,
  FOREIGN KEY(meeting_id) REFERENCES meetings(id) ON DELETE SET NULL
);
SQL
}

now() {
  date '+%Y-%m-%dT%H:%M:%S'
}

topic_id() {
  local name="$1"
  local id
  id=$(sqlite3 "$DB_PATH" "SELECT id FROM topics WHERE name = '$name';") || true
  if [[ -z "$id" ]]; then
    echo "Fehler: Thema '$name' existiert nicht." >&2
    exit 1
  fi
  echo "$id"
}

meeting_id() {
  local topic_name="$1"
  local meeting_title="$2"
  local t_id
  t_id=$(topic_id "$topic_name")
  local m_id
  m_id=$(sqlite3 "$DB_PATH" "SELECT id FROM meetings WHERE topic_id = $t_id AND title = '$meeting_title';") || true
  if [[ -z "$m_id" ]]; then
    echo "Fehler: Meeting '$meeting_title' für Thema '$topic_name' existiert nicht." >&2
    exit 1
  fi
  echo "$m_id"
}

read_body() {
  if [[ "${1:-}" != "" ]]; then
    printf '%s' "$1"
    return
  fi
  echo "Notiztext eingeben. Mit Ctrl-D beenden:"
  cat
}

print_help() {
  cat <<'TXT'
Notes CLI (bash + sqlite3)

Usage:
  ./notes.sh topic add <name>
  ./notes.sh topic list
  ./notes.sh meeting add <topic> <title> [--date YYYY-MM-DD]
  ./notes.sh meeting list <topic>
  ./notes.sh note add <topic> <title> [--meeting <meeting>] [--body <text>]
  ./notes.sh note list <topic> [--meeting <meeting>]
  ./notes.sh todo add <topic> <title> [--meeting <meeting>] [--body <text>]
  ./notes.sh todo list <topic> [--meeting <meeting>]
  ./notes.sh todo done <id>
  ./notes.sh capture <topic> <title> [--meeting <meeting>] [--todo]
TXT
}

list_entries() {
  local topic="$1"
  local meeting="${2:-}"
  local kind="${3:-}"
  local t_id
  t_id=$(topic_id "$topic")

  local where="e.topic_id = $t_id"
  if [[ -n "$meeting" ]]; then
    local m_id
    m_id=$(meeting_id "$topic" "$meeting")
    where+=" AND e.meeting_id = $m_id"
  fi
  if [[ -n "$kind" ]]; then
    where+=" AND e.type = '$kind'"
  fi

  sqlite3 -header -column "$DB_PATH" "
SELECT e.id, e.type, e.status, e.title, COALESCE(m.title, 'ohne Meeting') AS meeting, e.created_at
FROM entries e
LEFT JOIN meetings m ON e.meeting_id = m.id
WHERE $where
ORDER BY e.created_at DESC;
"
}

init_db

if [[ $# -lt 1 ]]; then
  print_help
  exit 0
fi

cmd="$1"; shift
case "$cmd" in
  topic)
    action="${1:-}"; shift || true
    case "$action" in
      add)
        name="${1:-}"
        [[ -n "$name" ]] || { echo "Fehler: Thema fehlt" >&2; exit 1; }
        ts=$(now)
        sqlite3 "$DB_PATH" "INSERT INTO topics(name, created_at) VALUES ('$name', '$ts');"
        echo "Thema angelegt: $name"
        ;;
      list)
        sqlite3 -header -column "$DB_PATH" "SELECT id, name, created_at FROM topics ORDER BY name;"
        ;;
      *) print_help; exit 1 ;;
    esac
    ;;

  meeting)
    action="${1:-}"; shift || true
    case "$action" in
      add)
        topic="${1:-}"; title="${2:-}"; shift 2 || true
        [[ -n "$topic" && -n "$title" ]] || { echo "Fehler: topic/title fehlt" >&2; exit 1; }
        date_value="$(date '+%Y-%m-%d')"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --date) date_value="$2"; shift 2 ;;
            *) echo "Fehler: Unbekannte Option $1" >&2; exit 1 ;;
          esac
        done
        t_id=$(topic_id "$topic")
        ts=$(now)
        sqlite3 "$DB_PATH" "INSERT INTO meetings(topic_id, title, happened_at, created_at) VALUES ($t_id, '$title', '$date_value', '$ts');"
        echo "Meeting angelegt: $title"
        ;;
      list)
        topic="${1:-}"
        [[ -n "$topic" ]] || { echo "Fehler: topic fehlt" >&2; exit 1; }
        t_id=$(topic_id "$topic")
        sqlite3 -header -column "$DB_PATH" "SELECT id, title, happened_at, created_at FROM meetings WHERE topic_id = $t_id ORDER BY happened_at DESC, title;"
        ;;
      *) print_help; exit 1 ;;
    esac
    ;;

  note|todo)
    action="${1:-}"; shift || true
    kind="NOTE"
    [[ "$cmd" == "todo" ]] && kind="TODO"

    case "$action" in
      add)
        topic="${1:-}"; title="${2:-}"; shift 2 || true
        [[ -n "$topic" && -n "$title" ]] || { echo "Fehler: topic/title fehlt" >&2; exit 1; }
        meeting=""
        body=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --meeting) meeting="$2"; shift 2 ;;
            --body) body="$2"; shift 2 ;;
            *) echo "Fehler: Unbekannte Option $1" >&2; exit 1 ;;
          esac
        done
        t_id=$(topic_id "$topic")
        m_id="NULL"
        if [[ -n "$meeting" ]]; then
          m_id=$(meeting_id "$topic" "$meeting")
        fi
        body_text=$(read_body "$body")
        ts=$(now)
        sqlite3 "$DB_PATH" "INSERT INTO entries(topic_id, meeting_id, type, title, body, created_at) VALUES ($t_id, $m_id, '$kind', '$title', '$body_text', '$ts');"
        echo "${cmd^} angelegt: $title"
        ;;
      list)
        topic="${1:-}"; shift || true
        [[ -n "$topic" ]] || { echo "Fehler: topic fehlt" >&2; exit 1; }
        meeting=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --meeting) meeting="$2"; shift 2 ;;
            *) echo "Fehler: Unbekannte Option $1" >&2; exit 1 ;;
          esac
        done
        list_entries "$topic" "$meeting" "$kind"
        ;;
      done)
        [[ "$cmd" == "todo" ]] || { echo "Fehler: done nur für todo" >&2; exit 1; }
        id="${1:-}"
        [[ -n "$id" ]] || { echo "Fehler: id fehlt" >&2; exit 1; }
        sqlite3 "$DB_PATH" "UPDATE entries SET status = 'DONE' WHERE id = $id AND type = 'TODO';"
        echo "Todo als erledigt markiert."
        ;;
      *) print_help; exit 1 ;;
    esac
    ;;

  capture)
    topic="${1:-}"; title="${2:-}"; shift 2 || true
    [[ -n "$topic" && -n "$title" ]] || { echo "Fehler: topic/title fehlt" >&2; exit 1; }
    meeting=""
    kind="NOTE"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --meeting) meeting="$2"; shift 2 ;;
        --todo) kind="TODO"; shift ;;
        *) echo "Fehler: Unbekannte Option $1" >&2; exit 1 ;;
      esac
    done
    t_id=$(topic_id "$topic")
    m_id="NULL"
    if [[ -n "$meeting" ]]; then
      m_id=$(meeting_id "$topic" "$meeting")
    fi
    body_text=$(read_body "")
    ts=$(now)
    sqlite3 "$DB_PATH" "INSERT INTO entries(topic_id, meeting_id, type, title, body, created_at) VALUES ($t_id, $m_id, '$kind', '$title', '$body_text', '$ts');"
    echo "Eintrag angelegt: $title"
    ;;

  -h|--help|help)
    print_help
    ;;
  *)
    print_help
    exit 1
    ;;
esac
