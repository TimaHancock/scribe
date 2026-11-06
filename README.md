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
| [ProjectLogTerminal.psm1](#terminal-commands) | `log` and `Save-Proof` for any PowerShell window, plus an optional transcript |
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

**Decisions.** When the entry starts with DECISION, a ticked box offers to
create a decision record too: `decisions\NNN-<slug>.md` (in a coding project,
`repo\docs\decisions\`, so it travels with the code), numbered after the last
one and filled in from the playbook's
[decision-record template](documentation-playbook/templates/03-decision-record.md).
The log entry links to it, and the record opens so you can add the context and
the options you weighed.

**Files.** Drop files anywhere on the log box (the dashed area at the bottom
says so) and each one is copied into the project's `evidence\exports` under
the naming rule (keeping its extension) with a PROOF line. While you drag, the
box turns blue and says how many files it will save. The copy is exact, so a file keeps any metadata it already had,
such as a photo's EXIF data.

### Copied text

Copy an error or some output, press **Ctrl+Alt+V**, and it's logged as a SAW
entry in the active project, word for word. One line goes inline as code;
several go in a code block. More than 50 lines are saved to
`evidence\terminal` as a `.txt` file with a PROOF line instead. A notification
shows what was logged.

Ctrl+Alt+V is also Paste Special in Office apps, and Scribe takes it while it
runs. Pick another `pasteHotkey` in [settings](#settings), or `""` for none.

### Sessions

**Start session** in the tray menu marks the start of a stretch of work on the
active project with a SESSION entry, and the tray tooltip shows the time
running. **End session...** asks where to pick up next time, logs that as a
NEXT entry, and logs how long the session lasted:

```markdown
- 09:00 **SESSION** Started
- 10:25 **NEXT** Compare the owner list with the HR roster
- 10:25 **SESSION** Ended after 1h 25m
```

Those lengths are what a writeup's "Time spent" will be added up from. During a
session, a notification nudges you after `idleReminderMinutes` (default 15)
with nothing logged. A session survives a Scribe restart.

Switching projects during a session moves it: the session ends on the old
project and starts on the new one, so each log gets its own share of the time.
A notification says how long was logged on the old one. No NEXT is asked for;
to leave one, end the session before switching. This happens however you
switch, including New project and New-Project.ps1.

```markdown
- 11:10 **SESSION** Ended after 1h 10m, switched to 2026-11-other-project
```

### Screenshots

When an image lands on the clipboard, a box shows a preview and the project it
will go to, and asks for a short description. Press Enter and the image is
saved in the project's `evidence\screenshots` as:

```
2026-10-16_0912_admin-panel-exposed-without-auth.png
```

and a PROOF line is added to the project's `log.md`. Esc skips the capture.
As you type, the box shows the file name it will save to.

To log what the screenshot shows as well, pick a tag under **Also log**
(SAW, FIX, TRY or DEAD; type its first letter) and edit the note, which starts
as the description. That entry is logged just before the PROOF line:

```markdown
- 14:33 **SAW** Proxy still answers 502 after the port change
- 14:33 **PROOF** ![[2026-10-26_1433_proxy-502-page.png]]
```

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
| Start session / End session... | Starts or ends a [work session](#sessions) on the active project |
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
  "pasteHotkey": "Ctrl+Alt+V",
  "previewLines": 6,
  "extraTags": [],
  "watchClipboard": true,
  "maxSlugLength": 50,
  "logFormat": "obsidian",
  "projectsFolder": "",
  "idleReminderMinutes": 15
}
```

| Setting | Default | Description |
| --- | --- | --- |
| `logHotkey` | `"Ctrl+Alt+L"` | Hotkey for the log box. |
| `pasteHotkey` | `"Ctrl+Alt+V"` | Hotkey that logs the clipboard's text as SAW. `""` turns it off. |
| `idleReminderMinutes` | `15` | During a session, remind after this many minutes with nothing logged (0 turns it off, up to 240). |
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
| `-Terminal` | Add the [terminal commands](#terminal-commands) to your PowerShell profiles instead of making shortcuts. With `-Uninstall`, remove them. |
| `-Transcript` | With `-Terminal`: also start a transcript in every new PowerShell window. |
| `-WhatIf` | Show what would change. |

The shortcuts run Windows PowerShell 5.1 hidden with
`-ExecutionPolicy Bypass` for this one script. The console may flash in the
taskbar for a moment at sign-in.

`-Terminal` sets up the [terminal commands](#terminal-commands) instead of the
shortcuts.

## Terminal commands

`ProjectLogTerminal.psm1` brings the running log to any PowerShell window,
Windows PowerShell 5.1 or PowerShell 7. Entries go to the active project, in
its log's format.

```powershell
log TRY Pointed the reverse proxy at port 8080
docker logs web --tail 20 | log SAW 'Proxy log after the change'
log DECISION Delete stale app registrations -Record
Get-NetTCPConnection -LocalPort 8080 | Save-Proof 'listening on 8080'
```

| Command | Does |
| --- | --- |
| `log TAG text...` | Adds an entry (`log` is short for `Add-ProjectLog`). Tab completes the tag. Piped output goes in a code block under the text, or is saved to `evidence\terminal` with a PROOF line past 50 lines. `-Record` on a DECISION also creates its decision record. |
| `... \| Save-Proof name` | Saves the output to `evidence\terminal\YYYY-MM-DD_HHMM_<name>.txt`, headed by the command that produced it, and logs a PROOF line. The output still shows on screen; `-Quiet` hides it. |
| `Start-ProjectTranscript` | Records the rest of the session to `evidence\terminal\..._transcript.txt`. |

To load them in every new window, add them to your PowerShell profiles:

```powershell
.\Install-Scribe.ps1 -Terminal                # log and Save-Proof
.\Install-Scribe.ps1 -Terminal -Transcript    # and a transcript of every session
.\Install-Scribe.ps1 -Terminal -Uninstall     # take them out again
```

This adds a marked block to `profile.ps1` for Windows PowerShell and for
PowerShell 7 in your Documents folder, keeping the rest of each file as it was.
Running it again replaces the block. Profiles only run when the execution
policy allows scripts; the installer warns if it doesn't.

A transcript records everything typed and printed, passwords included, so it's
off unless you ask for it. It stays in `evidence\`, which never leaves your
machine. Windows PowerShell 5.1 writes your user and machine name at the top of
each transcript, and the next transcript you start removes them from the
closed ones. PowerShell 7 never writes them.

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
| `CodingPython` | A coding project with a Python repository in `repo\` |
| `CodingPowerShell` | A coding project with a PowerShell module repository in `repo\` |

The two coding modules follow the
[Coding project module](documentation-playbook/type-modules/coding-project.md):
a private workspace (kickoff card, log, evidence, drafts) around `repo\`, the
code's own repository, which holds the README, changelog, CI workflow,
`docs\decisions\` and a skeleton named after the project. For a project called
`proxy lab`, that's the `proxy_lab` package (src layout, pytest, a first
decision record for the layout) or the `ProxyLab` module (manifest,
`Public\`/`Private\` loader, a Pester test). The skeleton's tests pass as
created. `repo\` starts as a Git repository when Git is installed, with
nothing committed. The LICENSE file is a placeholder until you choose one.

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
