# Toolkit

One tool per job, used the same way on every project, beats a perfect stack you keep switching between.

## Starter stack

Six free tools cover the whole lifecycle. Adopt these first and add others only when a project needs them.

| Job | Starter pick | Why this one |
| --- | --- | --- |
| Notes and running log | [Obsidian](https://obsidian.md/) | Notes stay as local Markdown files you can search and commit; free for work use since February 20, 2025 ([announcement](https://obsidian.md/blog/free-for-work/)) |
| Screenshots | [Flameshot](https://flameshot.org/) on any OS, or [ShareX](https://getsharex.com/) on Windows | Built-in arrows, boxes and numbered callouts. Redact with a solid box, never the blur or pixelate tools |
| Terminal capture | [Start-Transcript](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.host/start-transcript) in PowerShell; `script` on Linux and macOS | One command at session start records everything that follows |
| Diagrams | [Excalidraw](https://excalidraw.com/) for sketches, [draw.io](https://www.drawio.com/) for formal diagrams, [Mermaid](https://mermaid.js.org/) as code | Source files live next to the writeup and stay editable; GitHub renders Mermaid in Markdown |
| Publishing | A Git repo plus [GitHub Pages](https://pages.github.com/) | Versioned, free hosting at URLs you control |
| Safety net | [gitleaks](https://github.com/gitleaks/gitleaks) as a pre-commit hook, plus [ExifTool](https://exiftool.org/) | Stops secrets at commit time and strips image metadata |

## Full toolkit by job

Pick one tool per job and standardize on it. Platform limits are noted where they apply.

| Job | Tool | Use it for |
| --- | --- | --- |
| Notes | [Obsidian](https://obsidian.md/) | A local Markdown vault with links between notes; renders Mermaid diagrams |
| Notes | [Joplin](https://joplinapp.org/) | Open-source Markdown notes with end-to-end encrypted sync |
| Notes | OneNote | Common in Microsoft shops; harder to version or export cleanly |
| Screenshots | [Flameshot](https://flameshot.org/) | Cross-platform capture with annotation |
| Screenshots | [ShareX](https://getsharex.com/) | Windows only; capture, annotation, scrolling capture and GIF recording |
| Terminal | [Start-Transcript](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.host/start-transcript) | Records a PowerShell session to a text file |
| Terminal | `script` | Records a Linux or macOS shell session to a file |
| Terminal | [asciinema](https://asciinema.org/) | Lightweight terminal recordings that viewers can pause and copy text from |
| Terminal | [VHS](https://github.com/charmbracelet/vhs) | Scripted, repeatable terminal GIFs from a tape file |
| Screen recording | [OBS Studio](https://obsproject.com/) | Full demos and walkthrough videos |
| Screen recording | [ScreenToGif](https://www.screentogif.com/) | Windows only; short GIFs with a built-in editor |
| Diagrams | [draw.io](https://www.drawio.com/) | Formal architecture and network diagrams, on desktop or web |
| Diagrams | [Excalidraw](https://excalidraw.com/) | Hand-drawn style sketches of flows and concepts |
| Diagrams | [Mermaid](https://mermaid.js.org/) | Flowcharts and sequence diagrams written as text inside Markdown |
| Site | [Hugo](https://gohugo.io/) | A fast static site generator for a blog or portfolio |
| Site | [Zensical](https://zensical.org/) | The successor to Material for MkDocs, for documentation-style sites |
| Site | [Quartz](https://quartz.jzhao.xyz/) | Publishes an Obsidian vault as a website |
| Quality | [Vale](https://vale.sh/) | Lints prose against a style guide |
| Quality | [markdownlint](https://github.com/DavidAnson/markdownlint) | Catches Markdown formatting errors |
| Quality | [lychee](https://github.com/lycheeverse/lychee) | Finds broken links before readers do |
| Safety | [gitleaks](https://github.com/gitleaks/gitleaks) | Scans commits and full git history for secrets |
| Safety | [TruffleHog](https://github.com/trufflesecurity/trufflehog) | Finds leaked credentials and, for many types, checks whether they still work |
| Safety | [ExifTool](https://exiftool.org/) | Reads and strips image and document metadata |
| Safety | [pre-commit](https://pre-commit.com/) | Runs the scanners above automatically before every commit |

Avoid Material for MkDocs for new sites: it reaches end of life on November 5, 2026 ([release notes](https://github.com/squidfunk/mkdocs-material/releases)). Re-check this page yearly, because tools change faster than the rest of the playbook.
