# Logger

Small Windows tools that take the friction out of documenting projects, labs
and schoolwork as you go. They follow the capture system in
[documentation-playbook/](documentation-playbook/README.md): one folder layout
per project, one running log (`log.md`) and one file-naming rule.

| Tool | What it does |
| --- | --- |
| [New-Project.ps1](#new-projectps1) | Creates a project folder in the playbook's layout and makes it the active project |
| [Start-LogBox.ps1](#start-logboxps1) | A hotkey pop-up for adding tagged entries to the active project's `log.md` |
| [Save-Screenshot.ps1](#save-screenshotps1) | Saves clipboard screenshots with timestamped names into the active project and logs a PROOF line |
| `ProjectLog.psm1` | Shared module: the active project, the log format and file-name slugs |

All three scripts use the same **active project**, so a screenshot and a log
entry made a minute apart land in the same place. Change it from the log box's
tray menu, with `New-Project.ps1`, or with `Set-ActiveProject` after
`Import-Module .\ProjectLog.psm1`. It is stored in
`%APPDATA%\ProjectLog\active-project.txt` (override with the
`PROJECTLOG_CONFIG` environment variable).

See [ROADMAP.md](ROADMAP.md) for where this is heading.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (`powershell.exe`, built into Windows)

There's nothing to install. If your execution policy blocks the scripts, add
`-ExecutionPolicy Bypass` after `-STA` in the commands below.

## Typical session

```powershell
# Once per project
powershell.exe -STA -File .\New-Project.ps1

# Each work session (or put these in a Startup shortcut)
powershell.exe -STA -WindowStyle Hidden -File .\Start-LogBox.ps1
powershell.exe -STA -File .\Save-Screenshot.ps1
```

Then work. Press **Ctrl+Alt+L** to log what you tried, saw or fixed, and take
screenshots with any tool that copies to the clipboard.

## New-Project.ps1

Asks for a project name, a type module and a parent folder (a folder picker
opens), then builds the folder tree for that module with a kickoff-card
`README.md` and an empty `log.md`. The folder is named `YYYY-MM-<slug>`.
Afterward it offers to make the new folder the active project.

| Module | Use it for |
| --- | --- |
| `Core` | Anything without a type module |
| `ITProject` | Migrations, deployments, rollouts, decommissions |
| `Runbook` | Writing or overhauling one procedure |
| `TechEval` | Choosing a product, tool or approach |
| `Academic` | One graded task |
| `Capstone` | A multi-task capstone, one folder per task |

| Parameter | Description |
| --- | --- |
| `-Slug` | Project name, e.g. `"proxy lab"`. Prompted for if omitted. |
| `-Module` | One of the modules above. Prompted for if omitted. |
| `-Path` | Parent folder. A folder picker opens if omitted; it remembers the last one. |
| `-Tasks` | Number of task folders for `Capstone` (1-12). |
| `-SetActive` | Make the new folder the active project without asking. |
| `-WhatIf` | Show what would be created without creating it. |

```powershell
.\New-Project.ps1 -Slug "senior capstone" -Module Capstone -Tasks 3 -Path D:\Projects -SetActive
```

## Start-LogBox.ps1

Runs in the background with a tray icon. Press the hotkey (default
**Ctrl+Alt+L**) and a small box opens on the monitor your mouse is on, showing
the last few log lines. Type a tag, then the entry:

```
TRY Pointed the reverse proxy at port 8080
```

| Key | Action |
| --- | --- |
| Enter | Save and close |
| Shift+Enter | New line, for pasted output |
| Esc | Close without saving |

The tags are listed under the entry box. Hover one to see when to use it and an
example; click one to put it at the start of the entry, replacing a tag that's
already there. Tags are matched case-insensitively, so `try` works.

The time and the date heading are added for you, and a second entry in the
same minute drops its time. The tray menu has **New entry**, **Set active
project...**, **Open log** and **Exit**. If a remote session or another app
swallows the hotkey, double-click the tray icon instead.

| Parameter | Default | Description |
| --- | --- | --- |
| `-Project` | *(active project)* | Folder to make active before starting. |
| `-Hotkey` | `Ctrl+Alt+L` | Global hotkey, e.g. `Ctrl+Shift+F9`. Needs at least one modifier. |
| `-ExtraTags` | *(none)* | Tags to accept in addition to the playbook's. |
| `-PreviewLines` | `6` | Recent log lines shown in the box (0-20). |

## Save-Screenshot.ps1

Take a screenshot with any tool that copies to the clipboard (Win+Shift+S,
PrtScn, ShareX, Greenshot). A small dialog pops up with a preview and asks for
a short description. Press Enter and the image is saved as:

```
2026-10-16_0912_admin-panel-exposed-without-auth.png
```

By default it saves into the active project's `evidence\screenshots` and
appends a PROOF line to its `log.md`. With no active project it saves to
`.\evidence\screenshots` and logs nothing. The active project is re-read on
every capture, so switching projects needs no restart.

Leave the console open while you work. Press **Ctrl+C** in the console to stop.

| Key | Action |
| --- | --- |
| Enter | Save with the typed description |
| Esc | Skip this capture (nothing is saved) |

As you type, the dialog shows the file name it will save to.

If the clipboard gets an image with exactly the same pixels as the last one
you saved or skipped, the dialog doesn't open again. The Snipping Tool, for
example, copies the capture a second time when you close its window. To save
the same image twice, take a new screenshot.

| Parameter | Default | Description |
| --- | --- | --- |
| `-OutputDir` | active project's `evidence\screenshots` | Folder to save into. Created if missing. Relative paths resolve from the current location. |
| `-LogPath` | active project's `log.md` | Log file to append PROOF lines to. |
| `-NoLog` | off | Don't append PROOF lines, even when a project is active. |
| `-MaxSlugLength` | `50` | Maximum length of the description part of the file name (10-120). |

### How names are built

- **Timestamp:** the time the image landed on the clipboard, not the time you
  finished typing, in the format `yyyy-MM-dd_HHmm`.
- **Slug:** the description is lowercased. Accents are folded to plain
  letters (`é` → `e`), and every other run of non-alphanumeric characters
  becomes a single `-`. Long slugs are cut at a word boundary when one falls
  close enough to the limit.
- **Empty description:** the slug becomes `screenshot`.
- **Name collisions:** `-2`, `-3`, … are added rather than overwriting
  an existing file.

## Log format

Entries follow the playbook's running-log format:

```
## 2026-10-26 (times local, UTC-4)
14:32 TRY      Pointed the reverse proxy at port 8080.
      SAW      502 Bad Gateway. Proxy log:
               connect() failed (111: Connection refused)
      PROOF    evidence/screenshots/2026-10-26_1432_proxy-502.png
```

A new date heading is written when the day changes. Extra lines of an entry
are indented under its text. PROOF paths are relative to the log's folder and
use forward slashes when the image is inside it; otherwise the full path is
written.

## Privacy

Clipboard images carry no EXIF, GPS, or camera metadata, and the scripts
don't add any, so the saved PNGs are clean. Screenshots can still contain
sensitive client data. This repo's `.gitignore` excludes `evidence/` and
`*.png` so they are never committed by accident.

## Development

Tests for the shared module use Pester 5:

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester .\tests"
```

## Troubleshooting

- **"needs a single-threaded apartment"**: launch with
  `powershell.exe -STA -File ...`.
- **Nothing happens after a screenshot:** check that your tool copies to the
  clipboard. Some only save to a file. Text copies are ignored on purpose.
- **"Couldn't register Ctrl+Alt+L"**: another app already uses that hotkey
  (error 1409). Restart the log box with `-Hotkey`, or double-click the tray
  icon.
- **Dialog appears behind other windows:** it's set to stay on top, but some
  full-screen apps can still cover it. Alt+Tab to it.
