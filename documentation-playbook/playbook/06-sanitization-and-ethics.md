# Sanitization and ethics

Nothing leaves your machine until it passes a redaction pass. One leaked token, client name or employee email undoes the credibility the writeup was meant to build.

### What to scrub

| Category | Examples | Replace with |
| --- | --- | --- |
| Secrets | Passwords, API keys, tokens, cookies, private keys, connection strings | Nothing: remove them, then rotate anything that appeared in any capture |
| Identifiers | Tenant, subscription and object IDs; serial numbers; license keys | Consistent placeholders such as `<TENANT_ID>` |
| IPv4 addresses | Public and internal IPs | 192.0.2.0/24, 198.51.100.0/24 or 203.0.113.0/24, reserved for documentation ([RFC 5737](https://www.rfc-editor.org/rfc/rfc5737.html)) |
| IPv6 addresses | Any real prefix | 2001:db8::/32, the IPv6 documentation prefix (RFC 3849) |
| Domains and hosts | Internal hostnames, URLs, mail domains | example.com, example.net, example.org or the .example top-level domain ([RFC 2606](https://www.rfc-editor.org/rfc/rfc2606.html)) |
| People | Names, emails, usernames, photos, chat handles | Role-based fictional names, such as helpdesk.admin@example.com |
| Organizations | Client and employer names, logos, ticket numbers | A generic description, such as "a mid-size healthcare client" |
| Metadata | Photo EXIF and GPS, document author fields, git author emails, git history | Stripped copies; check the full history, not just the last commit |

### How redaction fails

- **Blur and pixelation are reversible.** Bishop Fox's Unredacter and the earlier Depix recover pixelated text, and the firm's policy is solid black bars only ([Bishop Fox](https://bishopfox.com/blog/unredacter-tool-never-pixelation)). NN/g's portfolio guide suggests blurring NDA material; use solid bars instead.
- **Overlays hide nothing.** A black box drawn over text in a document, or black-on-black text, leaves the words selectable. Delete the text at the source or use a true redaction tool, then test the export.
- **History remembers.** A secret removed in a later commit still lives in git history. Rotate it, then scan the whole history with gitleaks or TruffleHog before publishing.
- **The frame leaks.** URL bars, browser tabs, taskbar clocks, notifications and window titles often show what you redacted elsewhere.
- **Details identify.** A headcount, an unusual hostname or a dated timeline can identify a client without its name. Generalize until the story fits many organizations.

### Permissions and platform rules

- **Work material needs written permission.** NDAs, contracts and employer policy override this playbook. When in doubt, rebuild the scenario in a personal lab with fictional data and document that instead.
- **Platforms set publication rules.** Hack The Box allows public solutions only for retired content and free material, and warns that a machine can be expired while still active ([HTB guidelines](https://help.hackthebox.com/en/articles/5188925-streaming-writeups-walkthrough-guidelines)). Schools and certification bodies have similar rules for graded work and exam content.
- **Test only what you are authorized to test,** and state that authorization in the scope.
- **Report real vulnerabilities to the vendor first,** and publish only after coordinated disclosure ends.

### The redaction pass

1. Search the draft and repo for secret patterns: `password`, `secret`, `token`, `key=`, `BEGIN PRIVATE KEY`.
2. Run gitleaks or TruffleHog across the full git history.
3. Open every image at 100% zoom and check each edge of the frame.
4. Replace identifiers with the placeholder scheme above, the same way everywhere.
5. Strip metadata, for example `exiftool -all= image.png`, then delete the `_original` backup ExifTool leaves.
6. Export, then attack the export: select all text in PDFs and search for every name you removed.
7. Have a second person, or yourself a day later, review with fresh eyes.
