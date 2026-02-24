# Meeting Notes Board (HTML / CSS / JS)

Eine statische Notizen-App für gesperrte Umgebungen (kein Python, keine PowerShell, kein Build-Tool).

## Start

`index.html` per Doppelklick im Browser öffnen.

## Funktionsumfang

- Themen anlegen/löschen
- Meetings pro Thema anlegen/löschen
- Notizen und Todos anlegen, bearbeiten, löschen
- Todo-Status zwischen `Open` und `Done` umschalten
- Suche + Filter (Alle / Notizen / Todos)
- Lokale Speicherung in `localStorage`
- Backup via JSON Export / Import

## Dateien

- `index.html` – Struktur und Dialoge
- `styles.css` – Layout und Design
- `app.js` – komplette App-Logik

## Hinweis

Die Daten bleiben lokal im Browserprofil. Für Gerätewechsel regelmäßig JSON exportieren.
