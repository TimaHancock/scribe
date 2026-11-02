# CLAUDE.md

Notes for working in this repo.

## What this is

Windows PowerShell tools for low-friction project documentation, following the
capture system in `documentation-playbook/`:

- `ProjectLog.psm1`: shared logic, no UI. Active and recent projects,
  `settings.json`, the clipboard-watch lock, evidence file names, the
  running-log format (`Add-LogEntry`) and tags. Covered by `tests/`.
- `ProjectLogUI.psm1`: shared WinForms dialogs (the screenshot description box).
- `Start-Scribe.ps1`: the tray app. Hotkey log box plus the screenshot watcher,
  live settings reload. Formerly `Start-LogBox.ps1`.
- `Install-Scribe.ps1`: Start Menu and Startup shortcuts.
- `Save-Screenshot.ps1`: console version of the screenshot watcher (polls the
  clipboard sequence number), for one-off `-OutputDir`/`-LogPath` use.
- `New-Project.ps1`: scaffolds a project folder per type module.

State lives in `%APPDATA%\ProjectLog\` (`active-project.txt`,
`recent-projects.txt`, `settings.json`, `last-parent.txt`, `scribe.log`).
`PROJECTLOG_CONFIG` points at a different `active-project.txt` and moves all of
them with it; tests and smoke runs must set it so they never touch real state.

`ROADMAP.md` holds the planned direction.

There is no build step, no package manager, and no dependencies outside the
.NET Framework assemblies that ship with Windows.

## Hard constraints

- **Target Windows PowerShell 5.1 (`powershell.exe`).** The README and the
  examples run it with `powershell.exe -STA`. Don't use PowerShell 7-only
  syntax (`?:`, `??`, `?.`, `&&`/`||` pipeline chains, `-Parallel`,
  `ForEach-Object -Parallel`, `Clean {}` blocks).
- **STA is required.** `System.Windows.Forms.Clipboard` throws on MTA
  threads, and the script checks for this at startup. Keep that check.
- **Encoding.** The file is UTF-8 *without* a BOM. Windows PowerShell 5.1
  reads BOM-less scripts as ANSI, so any non-ASCII character outside a
  comment (string literals, regexes) will be garbled. Either keep code
  ASCII-only or re-save the file as UTF-8 *with* a BOM.
- **Scribe's message window only counts.** `Scribe.MessageWindow` (C# in
  `Start-Scribe.ps1`) receives `WM_HOTKEY` and `WM_CLIPBOARDUPDATE` and only
  bumps counters; the 100 ms UI timer reads them and runs the PowerShell. Never
  run PowerShell from `WndProc` or another thread.
- **One clipboard watcher at a time.** Scribe and `Save-Screenshot.ps1` both
  take `Enter-ClipboardWatch` before watching, so a screenshot never gets two
  prompts. Keep that for anything new that reacts to clipboard images.
- **`$script:busy` serializes dialogs in Scribe.** While a dialog is open,
  hotkey presses are dropped and clipboard changes wait. New dialogs set it too.
- **Saved files must stay metadata-free.** Images come from the clipboard and
  are written with `Image.Save(..., Png)`, so they carry no EXIF or GPS data.
  Don't add anything that embeds metadata (author, host name, paths).
- **Never commit screenshots.** `evidence/` and `*.png` are gitignored on
  purpose. They can contain client data.

## Code conventions

- Keep the code in the style that's already there: comments are short and
  explain *why*, `-LiteralPath` is used for file operations, and paths are
  resolved with `GetUnresolvedProviderPathFromPSPath` so relative paths
  follow the PowerShell location, not the process working directory.
- Helper functions are approved-verb `Verb-Noun` with a `param()` block.
- The P/Invoke type is guarded with `-as [type]` so the script can be
  re-run in the same session. Keep that guard on any new `Add-Type`.
- Dispose GDI objects (`Image`, `Form`). The main loop disposes the clipboard
  image in a `finally` block.

## Verifying changes

At minimum, do these:

1. Parse check under 5.1 (repeat for each changed script):
   ```powershell
   powershell.exe -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("C:\dev\logger\Save-Screenshot.ps1",[ref]$null,[ref]$e); $e'
   ```
   No output means there are no parse errors.
2. Run the module tests under 5.1:
   `powershell.exe -NoProfile -Command "Invoke-Pester .\tests"`.
   Add a test for any change to `ProjectLog.psm1` logic.
3. Don't run `Save-Screenshot.ps1` or `Start-Scribe.ps1` in the foreground;
   they block forever. `New-Project.ps1 ... -WhatIf` and
   `Install-Scribe.ps1 -WhatIf` are safe to run.
4. Scribe can be smoke-tested end to end from a scratch STA script: set
   `PROJECTLOG_CONFIG` to a temp folder, start Scribe with `Start-Process` and
   an unused `-Hotkey`, put an image on the clipboard, then find and drive its
   dialogs with UI Automation (`UIAutomationClient`), and send the hotkey with
   `keybd_event`. Two catches: it replaces the user's clipboard (say so first),
   and Scribe must be launched with `Start-Process -WindowStyle Minimized` plus
   powershell's own `-WindowStyle Hidden`, like the shortcut. Launched with
   `Start-Process -WindowStyle Hidden`, every dialog stays invisible.
5. Ask the user to do a manual run for focus and feel, for anything that
   touches a dialog, the clipboard handling or the hotkey.

## Docs

`README.md` is the user-facing doc. If you change parameters, defaults, the
file-name format, or the PROOF line format, update the comment-based help at
the top of the script and the README together.
