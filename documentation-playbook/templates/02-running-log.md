# Running log

Append one entry per event to `log.md`, newest at the bottom. The tags let you pull every dead end or decision out later with a single search, such as `**DEAD**`.

Each entry is a list item, so the log reads cleanly in Obsidian. Pasted output goes in a code block under its entry, and a PROOF line embeds the evidence file by name, so screenshots show inline.

````markdown
## YYYY-MM-DD (times local, UTC±N)
- HH:MM **TRY** What you ran or changed (exact command as text)
- HH:MM **SAW** Exact output, error or state, pasted as text
  ```
  Longer output on its own lines
  ```
- HH:MM **PROOF** ![[YYYY-MM-DD_HHMM_<slug>.png]]
- HH:MM **NEXT** What you will check next, and why
- HH:MM **DECISION** <choice>; see [[NNN-<slug>]]
- HH:MM **DEAD** What failed · time lost · lesson
- HH:MM **FIX** What started working, and what changed
- HH:MM **Q** Open question
- HH:MM **REF** <title> <url>; what it told you
````

Scribe adds one more tag of its own: SESSION, written when you start and end a work session from its tray menu (`Started`, then `Ended after 1h 25m`). The lengths add up to the writeup's "Time spent".

## Plain variant

For a log read in a text editor rather than Obsidian, use aligned columns instead. A second entry in the same minute leaves the time blank, and extra lines are indented under the text. Scribe writes this format when `logFormat` is `plain` in its settings; a log keeps whichever format its first entry used.

```text
## YYYY-MM-DD (times local, UTC±N)
HH:MM TRY       What you ran or changed (exact command as text)
      SAW       Exact output, error or state, pasted as text
      PROOF     evidence/<folder>/YYYY-MM-DD_HHMM_<slug>.<ext>
HH:MM DEAD      What failed · time lost · lesson
```
