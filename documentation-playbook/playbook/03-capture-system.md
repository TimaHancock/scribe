# Capture system

Capture only works when it is automatic: one folder layout, one log format and one naming rule, reused on every project. Set them up during Frame so nothing depends on remembering mid-task.

### Workspace layout

```text
YYYY-MM-project-slug/
  README.md        kickoff card now, final summary later
  log.md           running log, newest entry at the bottom
  decisions/       one short record per decision (NNN-slug.md)
  evidence/
    screenshots/   untouched originals; annotated copies beside them
    terminal/      transcripts and recordings
    exports/       configs, query results, raw data
  scripts/         anything you ran more than once
  diagrams/        editable sources (.drawio, .excalidraw, .mmd)
  drafts/          writeup drafts, one per depth layer
  publish/         sanitized copies only
```

Only `publish/` ever leaves your machine or private repo. Everything else is raw and stays private, so a forgotten screenshot cannot ship by accident.

Type modules adapt this layout. When a project uses a module, start from that module's Project directory tree instead ([Type Modules](../type-modules/README.md)). The core rule stays the same: only `publish/` leaves.

### Naming

Name every evidence file `YYYY-MM-DD_HHMM_short-description.ext`, for example `2026-10-07_1447_proxy-200-ok.png`. Names sort by time, survive copying, and match the log entry that points to them.

### Running log

Write one line per event, tagged so you can pull each kind out later with a search. Paste errors and output as text; save screenshots for things that only make sense visually.

```text
## 2026-10-07 (times local, UTC-4)
14:32 TRY      Pointed the reverse proxy at the app container on port 8080.
      SAW      502 Bad Gateway. Proxy log: connect() failed (111: Connection refused)
      PROOF    evidence/terminal/2026-10-07_1432_proxy-error.txt
      NEXT     Confirm which port the container listens on.
14:41 DEAD     Rebuilt the image; same error. Cost 9 min. Check ports before rebuilding.
14:47 FIX      App listens on 3000, not 8080. Updated upstream; 200 OK.
      PROOF    evidence/screenshots/2026-10-07_1447_proxy-200-ok.png
```

| Tag | Log it when | Feeds this writeup section |
| --- | --- | --- |
| TRY | You run or change something | Walkthrough |
| SAW | You observe output, an error or a state; paste it exactly | Walkthrough, Results |
| PROOF | You save an evidence file | Evidence beside the step |
| DECISION | You choose between options; link the record | Approach and decisions |
| DEAD | An attempt fails; add the time it cost and the lesson | Challenges and dead ends |
| FIX | Something starts working | Walkthrough |
| Q | A question opens | Next steps, or answered later |
| REF | A doc, post or tool helped | References and credits |

### Evidence rules

- **Before and after.** Capture the state before each change, the change itself and the state after.
- **Baseline first.** Measure the starting number before you touch anything; an improvement needs a before.
- **Context in frame.** Include the prompt, hostname, window title or clock when they prove where and when.
- **Text over pixels.** Commands, errors and output go into the log as text: searchable, copyable and readable by screen readers.
- **Record terminals automatically.** Start a transcript at the beginning of each session so nothing relies on copying by hand (tools in [Toolkit](../toolkit.md)).
- **Export configuration as files.** Save settings as JSON, YAML or scripts and commit them, rather than screenshotting settings pages.
- **Originals stay untouched.** Annotate and redact copies; keep the raw file for your own reference.

### Decisions and dead ends

When you choose between options, write a three-to-five line decision record before moving on. Michael Nygard's architecture decision records use title, context, decision, status and consequences, and keep reversed decisions marked superseded instead of deleting them ([Nygard 2011](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)).

Log each dead end within minutes, with its time cost and lesson; these become the Challenges section almost verbatim. Templates for both are in [Templates](../templates/README.md).
