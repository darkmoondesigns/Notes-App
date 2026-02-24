# Notes App (HTML/CSS/JS – ohne Python, ohne PowerShell)

Diese App läuft als **statische Web-App** und ist damit für stark eingeschränkte Umgebungen geeignet, in denen Skripte per Gruppenrichtlinie blockiert werden.

## Start

Einfach `index.html` im Browser öffnen (Doppelklick).

Keine Installation, kein Server, kein Python/PowerShell nötig.

## Features

- Themen anlegen
- Meetings innerhalb eines Themas
- Notizen pro Thema/Meeting
- Todos wie Notizen (inkl. `Done`-Status)
- Lokale Speicherung im Browser (`localStorage`)
- JSON Export/Import zur Sicherung

## Dateien

- `index.html` – Struktur/UI
- `styles.css` – Styling
- `app.js` – Logik + Speicherung

## Hinweis

Da alles lokal im Browser läuft, bleiben die Daten pro Browserprofil erhalten. Für Backup bitte regelmäßig den **Export JSON** verwenden.
