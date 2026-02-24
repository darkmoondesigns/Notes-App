# Notes App (Windows + Bash, ohne Python)

Diese Version läuft **ohne Python** und ist für geschlossene Umgebungen gedacht.

## Anforderungen

- `sqlite3` (unter Windows: `sqlite3.exe` im `PATH`)
- Entweder:
  - **Windows PowerShell** (empfohlen auf Windows) oder
  - **bash** (z. B. Git Bash / WSL)

## Windows Start (empfohlen)

```powershell
.\notes.ps1 --help
```

Oder via CMD-Wrapper:

```cmd
notes.cmd --help
```

## Bash Start

```bash
./notes.sh --help
```

Datenbank-Pfad standardmäßig:
- Windows: `%USERPROFILE%\.notes_app.db`
- Bash: `~/.notes_app.db`

Optional via Umgebungsvariable:

```powershell
$env:NOTES_DB_PATH='C:\temp\notes.db'; .\notes.ps1 topic list
```

```bash
NOTES_DB_PATH=/pfad/zur/db.sqlite ./notes.sh topic list
```

## Funktionen

- **Themen** anlegen/listen
- **Meetings** pro Thema
- **Notizen** pro Thema/Meeting
- **Todos** wie Notizen (inkl. `done`)
- **Capture-Modus** für schnelles Erfassen

## Beispiele (PowerShell)

```powershell
.\notes.ps1 topic add "Projekt Phoenix"
.\notes.ps1 meeting add "Projekt Phoenix" "Kickoff" --date 2026-02-24
.\notes.ps1 note add "Projekt Phoenix" "Agenda" --meeting "Kickoff" --body "Ziele, Rollen, Risiken"
.\notes.ps1 todo add "Projekt Phoenix" "Angebot prüfen" --meeting "Kickoff" --body "Bis Freitag"
.\notes.ps1 todo list "Projekt Phoenix"
.\notes.ps1 todo done 1
```

Interaktiv schnell erfassen:

```powershell
.\notes.ps1 capture "Projekt Phoenix" "Sofortnotiz" --meeting "Kickoff"
.\notes.ps1 capture "Projekt Phoenix" "Task aus Call" --todo
```
