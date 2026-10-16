# CLAUDE.md

Notes for working in this repo.

## What this is

A single Windows PowerShell script, `Save-Screenshot.ps1`, that polls the
clipboard for new images. For each one it shows a WinForms dialog with a
preview and a description box, then saves the image as
`YYYY-MM-DD_HHMM_<slug>.png`. If `-LogPath` is set, it also appends a
`HH:mm PROOF     <relative path>` line to that log. It is meant for collecting
evidence during security engagements and labs.

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

1. Parse check under 5.1:
   ```powershell
   powershell.exe -NoProfile -Command '$e=$null; [void][System.Management.Automation.Language.Parser]::ParseFile("C:\dev\screenshoter\Save-Screenshot.ps1",[ref]$null,[ref]$e); $e'
   ```
   No output means there are no parse errors.
2. For logic changes (slugging, unique paths, PROOF line formatting),
   dot-source the functions or copy them into a scratch script and call them
   directly. Don't run the whole script, because it blocks forever in the
   watch loop.
3. Ask the user to do a manual run for anything that touches the dialog,
   the clipboard handling, or the main loop:
   `powershell.exe -STA -ExecutionPolicy Bypass -File .\Save-Screenshot.ps1`

## Docs

`README.md` is the user-facing doc. If you change parameters, defaults, the
file-name format, or the PROOF line format, update the comment-based help at
the top of the script and the README together.
