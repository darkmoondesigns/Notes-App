param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'

function Get-DbPath {
    if ($env:NOTES_DB_PATH -and $env:NOTES_DB_PATH.Trim().Length -gt 0) {
        return $env:NOTES_DB_PATH
    }
    if ($env:USERPROFILE) {
        return (Join-Path $env:USERPROFILE '.notes_app.db')
    }
    return (Join-Path $HOME '.notes_app.db')
}

$DB_PATH = Get-DbPath

function Escape-Sql([string]$text) {
    if ($null -eq $text) { return '' }
    return $text.Replace("'", "''")
}

function Invoke-Sql([string]$sql, [switch]$Table) {
    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if (-not $sqlite) {
        $sqlite = Get-Command sqlite3.exe -ErrorAction SilentlyContinue
    }
    if (-not $sqlite) {
        throw "sqlite3 wurde nicht gefunden. Bitte sqlite3 installieren und in PATH aufnehmen."
    }

    if ($Table) {
        & $sqlite.Source -header -column $DB_PATH $sql
    } else {
        & $sqlite.Source $DB_PATH $sql
    }
}

function Init-Db {
    $schema = @"
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
"@
    Invoke-Sql $schema | Out-Null
}

function Now-Iso { Get-Date -Format 'yyyy-MM-ddTHH:mm:ss' }

function Get-TopicId([string]$topicName) {
    $name = Escape-Sql $topicName
    $id = (Invoke-Sql "SELECT id FROM topics WHERE name = '$name';" | Select-Object -First 1)
    if (-not $id) { throw "Thema '$topicName' existiert nicht." }
    return $id.Trim()
}

function Get-MeetingId([string]$topicName, [string]$meetingTitle) {
    $topicId = Get-TopicId $topicName
    $title = Escape-Sql $meetingTitle
    $id = (Invoke-Sql "SELECT id FROM meetings WHERE topic_id = $topicId AND title = '$title';" | Select-Object -First 1)
    if (-not $id) { throw "Meeting '$meetingTitle' für Thema '$topicName' existiert nicht." }
    return $id.Trim()
}

function Read-Body([string]$inlineBody) {
    if ($inlineBody) { return $inlineBody }
    Write-Host 'Notiztext eingeben. Mit Ctrl+Z und Enter beenden:'
    return [Console]::In.ReadToEnd().TrimEnd()
}

function Show-Help {
@"
Notes CLI (PowerShell + sqlite3)

Usage:
  .\notes.ps1 topic add <name>
  .\notes.ps1 topic list
  .\notes.ps1 meeting add <topic> <title> [--date YYYY-MM-DD]
  .\notes.ps1 meeting list <topic>
  .\notes.ps1 note add <topic> <title> [--meeting <meeting>] [--body <text>]
  .\notes.ps1 note list <topic> [--meeting <meeting>]
  .\notes.ps1 todo add <topic> <title> [--meeting <meeting>] [--body <text>]
  .\notes.ps1 todo list <topic> [--meeting <meeting>]
  .\notes.ps1 todo done <id>
  .\notes.ps1 capture <topic> <title> [--meeting <meeting>] [--todo]
"@ | Write-Host
}

function Parse-Option([string[]]$tokens, [string]$name) {
    $i = [Array]::IndexOf($tokens, $name)
    if ($i -ge 0 -and $i + 1 -lt $tokens.Length) { return $tokens[$i + 1] }
    return ''
}

Init-Db

if ($Args.Length -eq 0) {
    Show-Help
    exit 0
}

try {
    $cmd = $Args[0]
    $rest = if ($Args.Length -gt 1) { $Args[1..($Args.Length - 1)] } else { @() }

    switch ($cmd) {
        'topic' {
            if ($rest.Length -lt 1) { Show-Help; exit 1 }
            $action = $rest[0]
            switch ($action) {
                'add' {
                    if ($rest.Length -lt 2) { throw 'Thema fehlt.' }
                    $name = Escape-Sql $rest[1]
                    $ts = Now-Iso
                    Invoke-Sql "INSERT INTO topics(name, created_at) VALUES ('$name', '$ts');" | Out-Null
                    Write-Host "Thema angelegt: $($rest[1])"
                }
                'list' {
                    Invoke-Sql 'SELECT id, name, created_at FROM topics ORDER BY name;' -Table
                }
                default { Show-Help; exit 1 }
            }
        }

        'meeting' {
            if ($rest.Length -lt 1) { Show-Help; exit 1 }
            $action = $rest[0]
            switch ($action) {
                'add' {
                    if ($rest.Length -lt 3) { throw 'topic/title fehlt.' }
                    $topic = $rest[1]
                    $title = $rest[2]
                    $dateValue = Parse-Option $rest '--date'
                    if (-not $dateValue) { $dateValue = Get-Date -Format 'yyyy-MM-dd' }

                    $topicId = Get-TopicId $topic
                    $titleEsc = Escape-Sql $title
                    $ts = Now-Iso
                    Invoke-Sql "INSERT INTO meetings(topic_id, title, happened_at, created_at) VALUES ($topicId, '$titleEsc', '$dateValue', '$ts');" | Out-Null
                    Write-Host "Meeting angelegt: $title"
                }
                'list' {
                    if ($rest.Length -lt 2) { throw 'topic fehlt.' }
                    $topicId = Get-TopicId $rest[1]
                    Invoke-Sql "SELECT id, title, happened_at, created_at FROM meetings WHERE topic_id = $topicId ORDER BY happened_at DESC, title;" -Table
                }
                default { Show-Help; exit 1 }
            }
        }

        'note' {
            if ($rest.Length -lt 1) { Show-Help; exit 1 }
            $action = $rest[0]
            switch ($action) {
                'add' {
                    if ($rest.Length -lt 3) { throw 'topic/title fehlt.' }
                    $topic = $rest[1]
                    $title = $rest[2]
                    $meeting = Parse-Option $rest '--meeting'
                    $bodyArg = Parse-Option $rest '--body'
                    $body = Read-Body $bodyArg
                    $topicId = Get-TopicId $topic
                    $meetingId = 'NULL'
                    if ($meeting) { $meetingId = Get-MeetingId $topic $meeting }

                    $titleEsc = Escape-Sql $title
                    $bodyEsc = Escape-Sql $body
                    $ts = Now-Iso
                    Invoke-Sql "INSERT INTO entries(topic_id, meeting_id, type, title, body, created_at) VALUES ($topicId, $meetingId, 'NOTE', '$titleEsc', '$bodyEsc', '$ts');" | Out-Null
                    Write-Host "Note angelegt: $title"
                }
                'list' {
                    if ($rest.Length -lt 2) { throw 'topic fehlt.' }
                    $topic = $rest[1]
                    $meeting = Parse-Option $rest '--meeting'
                    $topicId = Get-TopicId $topic
                    $where = "e.topic_id = $topicId AND e.type = 'NOTE'"
                    if ($meeting) {
                        $meetingId = Get-MeetingId $topic $meeting
                        $where += " AND e.meeting_id = $meetingId"
                    }
                    Invoke-Sql "SELECT e.id, e.type, e.status, e.title, COALESCE(m.title, 'ohne Meeting') AS meeting, e.created_at FROM entries e LEFT JOIN meetings m ON e.meeting_id = m.id WHERE $where ORDER BY e.created_at DESC;" -Table
                }
                default { Show-Help; exit 1 }
            }
        }

        'todo' {
            if ($rest.Length -lt 1) { Show-Help; exit 1 }
            $action = $rest[0]
            switch ($action) {
                'add' {
                    if ($rest.Length -lt 3) { throw 'topic/title fehlt.' }
                    $topic = $rest[1]
                    $title = $rest[2]
                    $meeting = Parse-Option $rest '--meeting'
                    $bodyArg = Parse-Option $rest '--body'
                    $body = Read-Body $bodyArg
                    $topicId = Get-TopicId $topic
                    $meetingId = 'NULL'
                    if ($meeting) { $meetingId = Get-MeetingId $topic $meeting }

                    $titleEsc = Escape-Sql $title
                    $bodyEsc = Escape-Sql $body
                    $ts = Now-Iso
                    Invoke-Sql "INSERT INTO entries(topic_id, meeting_id, type, title, body, created_at) VALUES ($topicId, $meetingId, 'TODO', '$titleEsc', '$bodyEsc', '$ts');" | Out-Null
                    Write-Host "Todo angelegt: $title"
                }
                'list' {
                    if ($rest.Length -lt 2) { throw 'topic fehlt.' }
                    $topic = $rest[1]
                    $meeting = Parse-Option $rest '--meeting'
                    $topicId = Get-TopicId $topic
                    $where = "e.topic_id = $topicId AND e.type = 'TODO'"
                    if ($meeting) {
                        $meetingId = Get-MeetingId $topic $meeting
                        $where += " AND e.meeting_id = $meetingId"
                    }
                    Invoke-Sql "SELECT e.id, e.type, e.status, e.title, COALESCE(m.title, 'ohne Meeting') AS meeting, e.created_at FROM entries e LEFT JOIN meetings m ON e.meeting_id = m.id WHERE $where ORDER BY e.created_at DESC;" -Table
                }
                'done' {
                    if ($rest.Length -lt 2) { throw 'id fehlt.' }
                    $id = $rest[1]
                    Invoke-Sql "UPDATE entries SET status = 'DONE' WHERE id = $id AND type = 'TODO';" | Out-Null
                    Write-Host 'Todo als erledigt markiert.'
                }
                default { Show-Help; exit 1 }
            }
        }

        'capture' {
            if ($rest.Length -lt 2) { throw 'topic/title fehlt.' }
            $topic = $rest[0]
            $title = $rest[1]
            $meeting = Parse-Option $rest '--meeting'
            $isTodo = ($rest -contains '--todo')
            $kind = if ($isTodo) { 'TODO' } else { 'NOTE' }

            $body = Read-Body ''
            $topicId = Get-TopicId $topic
            $meetingId = 'NULL'
            if ($meeting) { $meetingId = Get-MeetingId $topic $meeting }

            $titleEsc = Escape-Sql $title
            $bodyEsc = Escape-Sql $body
            $ts = Now-Iso
            Invoke-Sql "INSERT INTO entries(topic_id, meeting_id, type, title, body, created_at) VALUES ($topicId, $meetingId, '$kind', '$titleEsc', '$bodyEsc', '$ts');" | Out-Null
            Write-Host "Eintrag angelegt: $title"
        }

        '-h' { Show-Help }
        '--help' { Show-Help }
        'help' { Show-Help }
        default { Show-Help; exit 1 }
    }
}
catch {
    Write-Error "Fehler: $($_.Exception.Message)"
    exit 1
}
