# CLAUDE.md

Notes for working in this repo.

## What this is

Windows PowerShell tools for low-friction project documentation, following the
capture system in `documentation-playbook/`:

- `ProjectLog.psm1`: the shared module. Active project, running-log format
  (`Add-LogEntry`), tags, and `ConvertTo-Slug`.
- `Start-LogBox.ps1`: tray app with a global hotkey that opens a box for
  adding tagged entries to the active project's `log.md`.
- `Save-Screenshot.ps1`: polls the clipboard for new images, asks for a
  description, saves `YYYY-MM-DD_HHMM_<slug>.png` into the active project and
  appends a PROOF line.
- `New-Project.ps1`: scaffolds a project folder per type module.

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
- **The hotkey and the tray icon live in `Start-LogBox.ps1`.** Its hotkey runs
  on a separate thread that only increments a counter, which a UI timer reads,
  so no PowerShell code ever runs off the UI thread. Keep it that way.
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

Claude can't drive the interactive loop end to end, because it needs a real
screenshot and a person typing into the dialog. At minimum, do these:

1. Parse check under 5.1 (repeat for each changed script):
   ```powershell
   powershell.exe -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("C:\dev\logger\Save-Screenshot.ps1",[ref]$null,[ref]$e); $e'
   ```
   No output means there are no parse errors.
2. Run the module tests under 5.1:
   `powershell.exe -NoProfile -Command "Invoke-Pester .\tests"`.
   Add a test for any change to `ProjectLog.psm1` logic.
3. For logic inside the scripts (unique paths, image hashing), copy the
   function into a scratch script and call it directly. Don't run
   `Save-Screenshot.ps1` or `Start-LogBox.ps1` whole, because they block
   forever. `New-Project.ps1 ... -WhatIf` is safe to run.
4. Ask the user to do a manual run for anything that touches a dialog,
   the clipboard handling, the hotkey or the main loops:
   `powershell.exe -STA -ExecutionPolicy Bypass -File .\Save-Screenshot.ps1`

## Docs

`README.md` is the user-facing doc. If you change parameters, defaults, the
file-name format, or the PROOF line format, update the comment-based help at
the top of the script and the README together.
