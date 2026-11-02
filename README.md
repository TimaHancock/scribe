# Logger

Small Windows tools that take the friction out of documenting projects, labs
and schoolwork as you go. They follow the capture system in
[documentation-playbook/](documentation-playbook/README.md): one folder layout
per project, one running log (`log.md`) and one file-naming rule.

| Tool | What it does |
| --- | --- |
| [Start-Scribe.ps1](#start-scribeps1) | A tray app: a hotkey log box for the running log, plus a screenshot watcher that saves and logs every capture |
| [Install-Scribe.ps1](#install-scribeps1) | Adds Scribe to the Start Menu and starts it when you sign in |
| [New-Project.ps1](#new-projectps1) | Creates a project folder in the playbook's layout and makes it the active project |
| [Save-Screenshot.ps1](#save-screenshotps1) | The console version of Scribe's screenshot watcher, for a one-off output folder |
| [Convert-Log.ps1](#convert-logps1) | Rewrites an older plain-format log in the Obsidian format |
| `ProjectLog.psm1`, `ProjectLogUI.psm1` | Shared modules: active and recent projects, settings, the log format, file names, dialogs |

Everything uses the same **active project**, so a screenshot and a log entry
made a minute apart land in the same place. Switch it from Scribe's tray menu
or log box, with `New-Project.ps1`, or with `Set-ActiveProject` after
`Import-Module .\ProjectLog.psm1`.

See [ROADMAP.md](ROADMAP.md) for where this is heading.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (`powershell.exe`, built into Windows)

There's nothing to install beyond these files. If your execution policy blocks
the scripts, add `-ExecutionPolicy Bypass` after `-STA` in the commands below.

## Getting started

```powershell
# Once: add Scribe to the Start Menu and sign-in, and start it now
powershell.exe -ExecutionPolicy Bypass -File .\Install-Scribe.ps1 -Start

# Once per project
powershell.exe -STA -File .\New-Project.ps1
```

Then work. Press **Ctrl+Alt+L** to log what you tried, saw or fixed, and take
screenshots with any tool that copies to the clipboard (Win+Shift+S, PrtScn,
ShareX, Greenshot).

### With Obsidian

Set `projectsFolder` in [settings](#settings) to the vault folder that holds
your projects, for example `"D:\\Vault\\Projects"`. Then:

- New-Project.ps1 creates projects there without asking where.
- Scribe's project lists include every project in it.
- Logs render as lists with screenshots embedded inline.
- **Open log in Obsidian** in the tray menu opens the log in the vault.
- `Projects.base`, added next to your projects, is a dashboard of every
  project with its status, module and last day logged.

## Start-Scribe.ps1

Runs in the background as a tray icon: a blue **S** while it watches for
screenshots, grey while that's paused. Hover it to see the active project.

### Log box

Press the hotkey (default **Ctrl+Alt+L**) and a small box opens on the monitor
your mouse is on, showing the last few log lines. Type a tag, then the entry:

```
TRY Pointed the reverse proxy at port 8080
```

| Key | Action |
| --- | --- |
| Enter | Save and close |
| Shift+Enter | New line, for pasted output |
| Ctrl+P | Open the project list |
| Esc | Close without saving |

The tags are listed under the entry box. Hover one to see when to use it and an
example; click one to put it at the start of the entry, replacing a tag that's
already there. Tags are matched case-insensitively, so `try` works.

The **Project** list at the top holds your recent projects, newest first, then
the other projects in `projectsFolder`, and **Choose folder...** for any other
folder. Switching there switches the active project everywhere.

The time and the date heading are added for you; see [Log format](#log-format).

### Screenshots

When an image lands on the clipboard, a box shows a preview and the project it
will go to, and asks for a short description. Press Enter and the image is
saved in the project's `evidence\screenshots` as:

```
2026-10-16_0912_admin-panel-exposed-without-auth.png
```

and a PROOF line is added to the project's `log.md`. Esc skips the capture.
As you type, the box shows the file name it will save to.

If the clipboard gets an image with exactly the same pixels as the last one
you saved or skipped, the box doesn't open again. The Snipping Tool, for
example, copies the capture a second time when you close its window. To save
the same image twice, take a new screenshot.

To copy images without being asked about them, untick **Watch for
screenshots** in the tray menu.

### Tray menu

| Item | Does |
| --- | --- |
| New log entry | Opens the log box (double-clicking the icon does too) |
| Project | Recent projects, then the rest of `projectsFolder`, with the active one ticked, and Choose folder... |
| New project... | Asks for a name, type and folder (`projectsFolder` to start with), runs [New-Project.ps1](#new-projectps1), makes the new project active and opens its kickoff card |
| Watch for screenshots | Pauses or resumes the screenshot watcher |
| Open log | Opens the active project's `log.md`: in Obsidian when the project is inside a vault, otherwise in the default app for `.md` |
| Open project folder | Opens the active project's folder |
| Convert log to Obsidian | Lists the projects whose logs are still in the plain format; pick one and confirm to run [Convert-Log.ps1](#convert-logps1) on it |
| Edit settings | Opens `settings.json`, creating it with the defaults first |
| Exit | Stops Scribe |

Double-click the icon if a remote session or another app swallows the hotkey.

### Parameters

Parameters override `settings.json`.

| Parameter | Description |
| --- | --- |
| `-Project` | Folder to make active before starting. |
| `-Hotkey` | Log box hotkey, e.g. `Ctrl+Shift+F9`. Needs at least one modifier. |
| `-ExtraTags` | Tags to accept in addition to the playbook's. |
| `-PreviewLines` | Recent log lines shown in the box (0-20). |
| `-NoScreenshots` | Start with the screenshot watcher paused. |

Only one Scribe runs at a time. If you start it from a console, hide the
console with `powershell.exe -STA -WindowStyle Hidden -File .\Start-Scribe.ps1`,
not with `Start-Process -WindowStyle Hidden`: a process started hidden from
outside also hides every dialog Scribe opens.

## Settings

`%APPDATA%\ProjectLog\settings.json`, opened from the tray menu's **Edit
settings**. Scribe applies saved changes within about five seconds and shows a
notification. A value it can't use is reported, and the default is used
instead.

```json
{
  "logHotkey": "Ctrl+Alt+L",
  "previewLines": 6,
  "extraTags": [],
  "watchClipboard": true,
  "maxSlugLength": 50,
  "logFormat": "obsidian",
  "projectsFolder": ""
}
```

| Setting | Default | Description |
| --- | --- | --- |
| `logHotkey` | `"Ctrl+Alt+L"` | Hotkey for the log box. |
| `previewLines` | `6` | Recent log lines shown in the box (0-20). |
| `extraTags` | `[]` | Extra single-word tags, such as `["FLAG", "LOOT"]`. |
| `watchClipboard` | `true` | Whether Scribe starts watching for screenshots. Changing it while Scribe runs pauses or resumes the watcher. |
| `maxSlugLength` | `50` | Longest description part of a file name (10-120). Save-Screenshot.ps1 uses it too. |
| `logFormat` | `"obsidian"` | Format for a new log: `"obsidian"` or `"plain"`. A log that already has entries keeps its own format. See [Log format](#log-format). |
| `projectsFolder` | `""` | Folder that holds your projects, usually in an Obsidian vault. Write each backslash as `\\`. New-Project.ps1 creates projects here, and Scribe lists the folders in it that have a `log.md`. |

The same folder holds the other state files: `active-project.txt`,
`recent-projects.txt`, `last-parent.txt` (New-Project's last folder) and
`scribe.log`, where Scribe records warnings and errors in case a notification
was hidden. Set the `PROJECTLOG_CONFIG` environment variable to the path of an
`active-project.txt` elsewhere to move all of them.

## Install-Scribe.ps1

Creates a **Scribe** shortcut in the Start Menu and in your Startup folder,
both pointing at `Start-Scribe.ps1` in this folder. Run it again if you move
the folder.

| Parameter | Description |
| --- | --- |
| `-Start` | Start Scribe now as well. |
| `-NoAutostart` | Only the Start Menu shortcut; removes the Startup one if present. |
| `-Uninstall` | Remove both shortcuts. Exit a running Scribe from its tray menu. |
| `-WhatIf` | Show what would change. |

The shortcuts run Windows PowerShell 5.1 hidden with
`-ExecutionPolicy Bypass` for this one script. The console may flash in the
taskbar for a moment at sign-in.

## New-Project.ps1

Asks for a project name and a type module, then builds the folder tree for
that module with a kickoff-card `README.md` and an empty `log.md`. The folder
is named `YYYY-MM-<slug>` and goes in `projectsFolder`, or wherever you pick
in a folder picker when that setting is empty. Afterward it offers to make the
new folder the active project.

The kickoff card, the academic kickoff additions and the runbook
`procedure.md` are read from the playbook's templates, so edit them there. The
README starts with frontmatter that Obsidian shows as properties:

```yaml
---
type: project
status: planning
module: none
started: 2026-11-02
updated: 2026-11-02
---
```

Change `status` by hand as the work moves along (planning, active, paused,
done). Scribe sets `updated` on each day you log. When the parent folder is in
an Obsidian vault and has no `.base` file yet, New-Project.ps1 also copies
[projects.base](documentation-playbook/templates/projects.base) there as
`Projects.base`, a Bases dashboard of all your projects.

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
| `-Path` | Parent folder. Defaults to `projectsFolder`; when that's empty a folder picker opens, remembering the last folder. |
| `-Tasks` | Number of task folders for `Capstone` (1-12). |
| `-SetActive` | Make the new folder the active project without asking. |
| `-WhatIf` | Show what would be created without creating it. |

```powershell
.\New-Project.ps1 -Slug "senior capstone" -Module Capstone -Tasks 3 -Path D:\Projects -SetActive
```

## Save-Screenshot.ps1

The same screenshot box as Scribe, in a console window, for when you want to
save to a specific folder or log. Press **Ctrl+C** in the console to stop.

```powershell
powershell.exe -STA -File .\Save-Screenshot.ps1 `
    -OutputDir C:\Labs\2026-10-proxy\evidence\screenshots `
    -LogPath   C:\Labs\2026-10-proxy\log.md
```

Only one of Scribe and Save-Screenshot.ps1 can watch the clipboard at a time,
so you never get two prompts for one screenshot. Untick **Watch for
screenshots** in Scribe's tray menu before starting this script.

| Parameter | Default | Description |
| --- | --- | --- |
| `-OutputDir` | active project's `evidence\screenshots` | Folder to save into. Created if missing. Relative paths resolve from the current location. With no active project: `.\evidence\screenshots`. |
| `-LogPath` | active project's `log.md` | Log file to append PROOF lines to. With no active project, nothing is logged. |
| `-NoLog` | off | Don't append PROOF lines, even when a project is active. |
| `-MaxSlugLength` | `maxSlugLength` setting | Maximum length of the description part of the file name (10-120). |

## Convert-Log.ps1

Rewrites a plain-format log in the Obsidian format. Scribe's tray menu runs it
too, under **Convert log to Obsidian**. Entries become list items
and extra lines go in code blocks. PROOF paths to images in the project become
embeds. The original is kept as `log.md.bak`.

```powershell
.\Convert-Log.ps1 -WhatIf                     # preview the active project's log
.\Convert-Log.ps1 -Path D:\Vault\Projects\2026-10-proxy-lab\log.md
```

## How names are built

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

Entries follow the playbook's [running-log template](documentation-playbook/templates/02-running-log.md).
A new date heading is written when the day changes. A new log uses the
`logFormat` setting. After the first entry, each log keeps its own format, so
the two never mix in one file.

**obsidian** (the default) renders as a list:

````markdown
## 2026-10-26 (times local, UTC-4)
- 14:32 **TRY** Pointed the reverse proxy at port 8080.
- 14:33 **SAW** 502 Bad Gateway. Proxy log:
  ```
  connect() failed (111: Connection refused)
  ```
- 14:33 **PROOF** ![[2026-10-26_1433_proxy-502.png]]
````

Extra lines of an entry go in a code block under it. A PROOF line embeds the
evidence file by name (`![[...]]` for images, `[[...]]` for other files). The
timestamped names are unique, so Obsidian finds the file anywhere in the vault.
A file outside the project folder is written as its full path.

**plain** lines up in columns for a text editor:

```
## 2026-10-26 (times local, UTC-4)
14:32 TRY      Pointed the reverse proxy at port 8080.
      SAW      502 Bad Gateway. Proxy log:
               connect() failed (111: Connection refused)
      PROOF    evidence/screenshots/2026-10-26_1432_proxy-502.png
```

A second entry in the same minute drops its time, and extra lines are
indented under the text. PROOF paths are relative to the log's folder when
the file is inside it.

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
- **Nothing happens after a screenshot:** check that the tray icon is blue,
  not grey (grey means paused), and that your tool copies to the clipboard.
  Some only save to a file. Text copies are ignored on purpose.
- **No dialogs appear at all:** Scribe was started hidden from outside (see
  [Parameters](#parameters)). Exit it from the tray and start it from the
  Start Menu shortcut.
- **"Couldn't register Ctrl+Alt+L"**: another app already uses that hotkey
  (error 1409). Change `logHotkey` in settings, or double-click the tray icon.
- **"Scribe is already watching the clipboard"** from Save-Screenshot.ps1:
  untick **Watch for screenshots** in Scribe's tray menu first.
- **A notification didn't show:** Focus Assist may have hidden it. Warnings
  and errors are also written to `%APPDATA%\ProjectLog\scribe.log`. Scribe
  clears its notifications from the notification center about 10 seconds
  after showing them, so look in that file for older ones.
- **Dialog appears behind other windows:** it's set to stay on top, but some
  full-screen apps can still cover it. Alt+Tab to it.
