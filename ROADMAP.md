# Roadmap

Goal: make documentation as easy as breathing. Every capture should take one
keystroke, land in the right project, and read well in Obsidian, and the
writeup should be assembled from the log instead of from memory.

## Where things stand

The four tools (`Save-Screenshot.ps1`, `Start-LogBox.ps1`, `New-Project.ps1`,
`ProjectLog.psm1`) each remove a real piece of friction, and they share one
source of truth: the active project in `%APPDATA%\ProjectLog\active-project.txt`.

Gaps:

- They are four separate tools you have to remember to start, and the
  screenshot watcher needs a console window left open.
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

- One tray app (e.g. `Start-Scribe.ps1`) runs the hotkey, the log box and the
  clipboard watcher. No console windows, no Ctrl+C.
- Event-driven clipboard watching with `AddClipboardFormatListener` instead of
  the 400 ms polling loop.
- Autostart with a Startup shortcut, created by an `Install-Scribe.ps1`.
- A settings file (`%APPDATA%\ProjectLog\config.json`) for the vault root,
  hotkeys, log format and recent projects.
- Switching projects from a recent list in the tray menu and the log box,
  instead of a folder picker every time.
- One process writing to `log.md`, so entries from screenshots and the log box
  can't get mixed together.

## Phase 2: Obsidian-native output

- A log format option (`plain` or `obsidian`). The Obsidian format renders well
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

  The playbook's running-log template and the parser change together. A
  converter for old logs is easy to write either way.
- Projects live inside the vault; the project picker lists the folders under
  `<vault>/Projects/`.
- README frontmatter (`status`, `module`, `started`, `type`) written by
  `New-Project.ps1`, so an Obsidian Bases dashboard can show every project with
  its status and last activity.
- "Open in Obsidian" from the tray using `obsidian://open?vault=...&file=...`
  URIs, instead of opening `log.md` in Notepad.
- `New-Project.ps1` reads `documentation-playbook/templates/` instead of copies
  pasted into the script, so a template is edited in one place.

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

Phase 0, Phase 1, then the clipboard-text hotkey and terminal `log` function
from Phase 3, then Phase 2, then `Export-LogDigest`, then the rest.

Decide early on the log format switch in Phase 2. It changes the playbook's
running-log template and is easier before many logs exist in the old format.
