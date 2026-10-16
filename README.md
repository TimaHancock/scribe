# Screenshoter

Saves screenshots straight from the clipboard, with consistent timestamped
names, so you don't stop mid-test to save and rename files by hand.

Take a screenshot with any tool that copies to the clipboard (Win+Shift+S,
PrtScn, ShareX, Greenshot). A small dialog pops up with a preview and asks for
a short description. Press Enter and the image is saved as:

```
2026-10-16_0912_admin-panel-exposed-without-auth.png
```

The script can also append a `PROOF` line to a running engagement log, so
every saved image is recorded in your notes.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1 (`powershell.exe`, built into Windows)

There's nothing to install.

## Usage

Run from the folder where you want `evidence\screenshots` created:

```powershell
powershell.exe -STA -File .\Save-Screenshot.ps1
```

To save into a specific project and keep a log:

```powershell
powershell.exe -STA -File .\Save-Screenshot.ps1 `
    -OutputDir C:\Labs\2026-10-proxy\evidence\screenshots `
    -LogPath   C:\Labs\2026-10-proxy\log.md
```

Leave the console open while you work. Press **Ctrl+C** in the console to stop.

If your execution policy blocks the script, add `-ExecutionPolicy Bypass`
after `-STA`.

### In the dialog

| Key | Action |
| --- | --- |
| Enter | Save with the typed description |
| Esc | Skip this capture (nothing is saved) |

As you type, the dialog shows the file name it will save to.

If the clipboard gets an image with exactly the same pixels as the last one
you saved or skipped, the dialog doesn't open again. The Snipping Tool, for
example, copies the capture a second time when you close its window. To save
the same image twice, take a new screenshot.

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-OutputDir` | `evidence\screenshots` | Folder to save into. Created if missing. Relative paths resolve from the current location. |
| `-LogPath` | *(none)* | Optional log file (for example `log.md`). A PROOF line is appended for each saved image. |
| `-MaxSlugLength` | `50` | Maximum length of the description part of the file name (10–120). |

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

When `-LogPath` is set, each save adds a line like this:

```
09:12 PROOF     evidence/screenshots/2026-10-16_0912_admin-panel-exposed-without-auth.png
```

If the image is inside the log file's folder, the path is relative to that
folder and uses forward slashes, so it works as a Markdown link. Otherwise
the full path is written.

## Privacy

Clipboard images carry no EXIF, GPS, or camera metadata, and the script
doesn't add any, so the saved PNGs are clean. Screenshots can still contain
sensitive client data. This repo's `.gitignore` excludes `evidence/` and
`*.png` so they are never committed by accident.

## Troubleshooting

- **"Clipboard access needs a single-threaded apartment"**: launch with
  `powershell.exe -STA -File ...`.
- **Nothing happens after a screenshot:** check that your tool copies to the
  clipboard. Some only save to a file. Text copies are ignored on purpose.
- **Dialog appears behind other windows:** it's set to stay on top, but some
  full-screen apps can still cover it. Alt+Tab to it.
