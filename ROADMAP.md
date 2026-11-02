# Roadmap

Goal: make documentation as easy as breathing. Every capture should take one
keystroke, land in the right project, and read well in Obsidian, and the
writeup should be assembled from the log instead of from memory.

## Where things stand

When this roadmap was written, the four tools (`Save-Screenshot.ps1`,
`Start-LogBox.ps1`, `New-Project.ps1`, `ProjectLog.psm1`) each removed a real
piece of friction, and they shared one source of truth: the active project in
`%APPDATA%\ProjectLog\active-project.txt`.

Gaps:

- They were four separate tools you had to remember to start, and the
  screenshot watcher needed a console window left open. (Fixed in Phase 1.)
- They cover the playbook's first two phases (Frame, Capture). Distill, Draft,
  Review and Publish are still done by hand.
- The aligned plain-text log loses its alignment in Obsidian's reading view,
  and PROOF paths are plain text, so screenshots don't show inline.

## Approach

Don't start a full app yet. Merge everything into one PowerShell tray app that
starts at login, make the output Obsidian-native, then automate the back half
of the playbook. The C# already inside `Add-Type` makes a later .NET port cheap
if the PowerShell ceiling is reached.

## Phase 0: Fix the foundation

- [x] Restore the pixel-hash dedupe in `Save-Screenshot.ps1` (lost in `428c017`).
- [x] Finish the tag-link click handler in `Start-LogBox.ps1`.
- [x] Move `ConvertTo-Slug` into `ProjectLog.psm1`, used by both scripts.
- [x] Pester tests for the module's logic (`tests/ProjectLog.Tests.ps1`).
- [x] Rewrite the README to cover the whole toolset; fix the stale path in `CLAUDE.md`.

## Phase 1: One app, always running

- [x] One tray app, `Start-Scribe.ps1`, runs the hotkey, the log box and the
  clipboard watcher. No console windows, no Ctrl+C.
- [x] Event-driven clipboard watching with `AddClipboardFormatListener` instead
  of the 400 ms polling loop.
- [x] Start Menu and Startup shortcuts, created by `Install-Scribe.ps1`.
- [x] `%APPDATA%\ProjectLog\settings.json` for the hotkey, preview lines, extra
  tags, screenshot watching and slug length, applied live when saved. The vault
  root and log format arrive with Phase 2, which uses them. Recent projects are
  app state, so they live in `recent-projects.txt` instead.
- [x] Switching projects from a recent list in the tray menu and the log box
  (Ctrl+P), instead of a folder picker every time.
- [x] One process writing to `log.md`. `Save-Screenshot.ps1` stays as a console
  option, and a shared lock stops it and Scribe both prompting for one
  screenshot.

## Phase 2: Obsidian-native output

- [x] A log format option (`plain` or `obsidian`). The Obsidian format renders well
  and stays easy to grep:

  ````markdown
  ## 2026-10-26 (times local, UTC-4)
  - 14:32 **TRY** Pointed the reverse proxy at port 8080
  - 14:33 **SAW** 502 Bad Gateway
    ```
    connect() failed (111: Connection refused)
    ```
  - 14:33 **PROOF** ![[2026-10-26_1433_proxy-502.png]]
  ````

  `obsidian` is the default for new logs; a log keeps the format of its
  existing entries. The playbook's running-log template changed with it, and
  `Convert-Log.ps1` converts old logs.
- [x] Projects live inside the vault: `projectsFolder` in settings.json, and
  the project pickers list its folders that have a `log.md`.
- [x] README frontmatter (`type`, `status`, `module`, `started`, `updated`)
  from the kickoff card template. Scribe sets `updated` each day you log, and
  `Projects.base` (an Obsidian Bases dashboard) shows every project with its
  status and last activity.
- [x] "Open log in Obsidian" from the tray using `obsidian://open?path=...`
  URIs, instead of opening `log.md` in Notepad.
- [x] `New-Project.ps1` reads `documentation-playbook/templates/` and the type
  modules instead of copies pasted into the script, so a template is edited in
  one place.

## Phase 2.5: Project tools in the tray

- [x] **New project...** in the tray menu: a dialog for name, type, task count
  and parent folder (starting at `projectsFolder`) that shows the folder name
  and refuses one that exists, then runs `New-Project.ps1`, makes the project
  active and opens its kickoff card.
- [x] **Convert log to Obsidian** in the tray menu: lists the projects whose
  logs are still plain and runs `Convert-Log.ps1` on the one you pick, after a
  confirmation.

## Phase 3: More ways to capture, each one keystroke

- Copied text goes straight into the log: copy an error, press `Ctrl+Alt+V`,
  and it's logged as a SAW entry in a code block.
- Terminal integration: a profile snippet starts `Start-Transcript` into
  `evidence/terminal/`, and adds a `log TRY "..."` function and a
  `| Save-Proof name` pipe that saves command output and writes the PROOF line.
- A DECISION entry offers to create `decisions/NNN-slug.md`, filled in, with the
  link added to the log.
- Drop a file on the log box and it's copied into `evidence/exports/` under the
  naming rule, with a PROOF line.
- Sessions: start and stop from the tray; stopping asks for a NEXT. Logged time
  fills in "Time spent" in the writeup. Optional "nothing logged in 30 min"
  reminder.
- A tag field in the screenshot dialog (PROOF by default, or SAW/FIX with a
  note), so one capture can produce a two-line entry.

## Phase 4: Automate Distill to Publish

- `Export-LogDigest` reads `log.md` and writes `drafts/outline.md` in the
  master-writeup layout: DEAD to Challenges, DECISION to Approach, REF to
  References, open Q to Next steps, PROOF to an evidence gallery, plus time per
  day.
- `Invoke-RedactionScan` automates the first steps of the redaction pass:
  secrets, real IPs (outside the RFC 5737 documentation ranges), emails, GUIDs
  and hostnames. It keeps a placeholder mapping file so replacements stay
  consistent, and runs gitleaks if installed.
- `Publish-Project` copies drafts to `publish/`, checks every image has alt
  text, runs a link check, and walks the quality-bar checklist.
- Optional AI drafting of the summary and retro from the digest. Off by
  default, opt-in per project, and only after the redaction scan, because logs
  can contain client data.

## Phase 5: Port only if the limits are hit

Move to a C# .NET tray app (one exe, the same module logic) only if:

- the UI needs more than WinForms in PowerShell can reasonably do (rich
  autocomplete, inline image annotation);
- antivirus starts flagging `Add-Type`; or
- it's needed on a machine where scripts can't run.

An Obsidian plugin is the wrong main path: it can't capture while Obsidian is in
the background, and capturing is the whole point.

## Order

Phases 0, 1, 2 and 2.5 are done. Next: the clipboard-text hotkey and terminal
`log` function from Phase 3, then `Export-LogDigest`, then the rest.
