# Notes App (Bash + SQLite)

Diese Version läuft **ohne Python** und ist für geschlossene Umgebungen gedacht.

## Anforderungen

- `bash`
- `sqlite3`

## Start

```bash
./notes.sh --help
```

Datenbank-Pfad standardmäßig: `~/.notes_app.db`.
Optional via Umgebungsvariable:

```bash
NOTES_DB_PATH=/pfad/zur/db.sqlite ./notes.sh topic list
```

## Funktionen

- **Themen** anlegen/listen
- **Meetings** pro Thema
- **Notizen** pro Thema/Meeting
- **Todos** wie Notizen (inkl. `done`)
- **Capture-Modus** für schnelles Erfassen

## Beispiele

```bash
./notes.sh topic add "Projekt Phoenix"
./notes.sh meeting add "Projekt Phoenix" "Kickoff" --date 2026-02-24
./notes.sh note add "Projekt Phoenix" "Agenda" --meeting "Kickoff" --body "Ziele, Rollen, Risiken"
./notes.sh todo add "Projekt Phoenix" "Angebot prüfen" --meeting "Kickoff" --body "Bis Freitag"
./notes.sh todo list "Projekt Phoenix"
./notes.sh todo done 1
```

Interaktiv schnell erfassen:

```bash
./notes.sh capture "Projekt Phoenix" "Sofortnotiz" --meeting "Kickoff"
./notes.sh capture "Projekt Phoenix" "Task aus Call" --todo
```
