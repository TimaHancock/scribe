# Module: Runbook or SOP

Status: Drafting · Last reviewed: 2026-10-19

A procedure gets used, not read. Its reader is in the middle of the task, often under pressure and sometimes doing it for the first time. So this module drops most of the writeup's narrative and keeps exact steps, expected results and the points where you should stop.

## Covers and readers

**Covers:**

- **Runbooks:** what to do when an alert fires or a service fails.
- **SOPs:** routine tasks that must meet a standard, such as onboarding and offboarding users, monthly patching or quarterly access reviews.
- **How-to guides:** occasional tasks, such as renewing a certificate or adding a site to a managed fleet.

All three use one skeleton. An SOP adds compliance fields: owner, approval, review date and the records to keep.

**Doesn't cover:** why a system is designed the way it is (that goes in a project's handover pack), tutorials for learning a tool, or reference data such as IP tables and configuration values. Link to those; don't copy them into the procedure.

| Reader | What they need |
| --- | --- |
| Operator doing a routine task | Exact steps, the expected result of each, and when to stop |
| On-call responder | Diagnosis first, the fastest safe fix, and who to escalate to |
| New team member | Prerequisites and the context they don't have yet |
| Auditor | Proof the procedure exists, is followed and gets reviewed |
| Future you, automating it | Steps clean enough to turn into code one at a time |

## Template changes

Replace the master writeup with this skeleton. No narrative, no "I", and only the current state: history goes in the change history at the bottom.

```markdown
# <Verb> <object>            e.g. "Offboard a departing user"
Owner: <role> · Last tested: YYYY-MM-DD by <name> · Review by: YYYY-MM-DD
Applies to: <system, environment>

## When to use
The trigger (ticket type, alert name, schedule). When NOT to use it.

## Before you start
Role or permissions needed · tools · time estimate · user impact · approvals
Variables: <USER_UPN>, <TICKET_ID>

## Steps
1. One action per step, imperative verb first.
   Command in a code block, with <PLACEHOLDERS> from Variables.
   Expected result: what you should see.
2. WARNING before any destructive step: what it destroys, and the dry run to do first.
3. If <condition>, go to step 7. Otherwise, continue.

## Verify
How you know it worked: a check and its expected output.

## If something goes wrong
Rollback steps, and the conditions that mean stop and escalate.

## Escalation
Who, how to reach them, and when.

## Records
What to note in the ticket or log (required for SOPs).

## Change history
Date · change · author
```

**Writing rules,** from the [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/procedures-instructions/writing-step-by-step-instructions):

- Start each step with an imperative verb, and say where before what ("In Entra admin center, select Users").
- One action per step. Include the step that completes the task, such as Save.
- Keep a procedure to roughly 10 steps. Split longer ones into sub-procedures and link them in order.
- Make commands copy-pasteable: placeholders in angle brackets, declared once at the top.

**Runbook variant for alerts:** name the page after the alert, then use Symptoms, Impact, Diagnosis, Fix by cause, and Escalation in place of Steps. [GitLab's runbooks](https://runbooks.gitlab.com/) use one page per alert, grouped by service.

**Portfolio version:** internal runbooks rarely publish as they are. Publish a sanitized sample SOP for a common task, or a case study about building the runbook library.

## Project directory

Procedures need two layouts: a short-lived workspace for writing or overhauling one procedure, and a permanent library where the team finds them.

**Authoring workspace** (one procedure). It drops `decisions/`, `diagrams/` and `drafts/` from the core layout, because `procedure.md` is the draft and choices go in its change history.

```text
YYYY-MM-procedure-slug/
  README.md          trigger, owner, audience, and where it will live
  log.md             the first real run, command by command
  procedure.md       (new) the procedure, in the skeleton above
  evidence/
    runs/            (new) one file per test run: who, date, environment,
                     timings, deviations
    screenshots/     GUI steps, dated
    terminal/        output that becomes the Expected result text
  scripts/
    do-nothing.ps1   (new) stage 2 of the automation path, if started
  publish/           a sanitized sample SOP, if any
```

**Library** (in Git, or mirrored in the team's documentation platform). One folder per service, one page per alert, after [GitLab's runbooks](https://runbooks.gitlab.com/).

```text
runbooks/
  README.md            index: every procedure, owner, last tested, review by
  _templates/
    procedure.md       the skeleton above
    alert.md           the alert variant
  <service>/
    README.md          what the service does, owners, escalation contacts
    alerts/
      <AlertName>.md   named exactly after the alert
    sops/
      offboard-user.md
    how-to/
      renew-certificate.md
  _archive/            retired procedures, each saying what replaced it
```

When a procedure is finished, move `procedure.md` into the library and keep the authoring workspace as private evidence of how it was tested. Keep the index in README.md current: it is how stale procedures get noticed.

## Capture specifics and evidence standard

Write the procedure while you do the task, not from memory afterward. The first real run is the draft.

- **Commands and outputs:** log every command you run and a sanitized copy of its output. The output becomes the expected result.
- **Timings:** note how long each step took. The total becomes the time estimate.
- **Decision points:** each time you had to check something before choosing what to do next, that becomes an "If ..., go to step N" branch.
- **GUI steps:** capture them with Save-Screenshot.ps1 and note the date. Prefer text instructions over screenshots, because portals change their layout often and a stale screenshot misleads.
- **Surprises:** anything that went wrong becomes a warning, a pre-check or a stop condition.

A procedure is **tested** when someone other than the author has run it from the document alone, on a real or test system, without asking questions. Record that person and date in "Last tested."

| Claim | What proves it |
| --- | --- |
| "It works" | A run by a second person from the document alone, dated |
| "Takes 15 minutes" | Measured step timings from real runs |
| "Safe to run" | Dry-run output, and a rollback that was actually tested |
| "Current" | Last tested after the most recent change to the system it covers |

Every step that changes state is followed by a check and its expected output.

## Safety and rules

A procedure gets run by people who trust it, so its mistakes spread. These rules sit on top of the core redaction pass.

- **Warn before, not after.** Put the warning above a destructive or irreversible step. Say what it destroys and how many objects it touches, and give the dry run to do first, such as PowerShell's `-WhatIf`.
- **Name the least privilege needed.** State the specific role ("User Administrator"), not "an admin," and say how to elevate if you use just-in-time access such as PIM.
- **Label the environment.** Say at the top and in each command whether the target is production or test.
- **Stop conditions.** Write "Stop and escalate if ..." wherever continuing could make things worse.
- **No secrets.** Point to the vault entry by name. Never paste passwords, keys or tokens into the procedure or its example output.
- **SOPs that are controls.** If an SOP is evidence for an audit, such as offboarding, record any deviation in the ticket, and change the SOP only through a change record.
- **Internal doesn't mean harmless.** Hostnames, IP ranges and admin URLs in a runbook map your environment for an attacker. Redact them before a runbook leaves the team.

## Keeping it alive

A procedure no one has tested in a year is a guess. Unlike a project writeup, it is never finished.

- **One owner per procedure:** a role or a named person who approves changes and answers questions.
- **Fix it when you use it:** if you had to deviate from the steps, the document is wrong. Fix it before closing the ticket, or leave a note for the owner.
- **Review triggers:** any change to the system it covers, any incident where the procedure was wrong or missing, the owner leaving, and a set interval (every 6 to 12 months; annually at least for audit controls).
- **Test it with newcomers.** Having a new team member run it with you watching is the fastest way to find the steps you skipped.
- **Retire it.** When a system is decommissioned, archive its procedures and say what replaced them.

### Path to automation

A clean procedure is the first step toward a script. Dan Slimmon's [do-nothing scripting](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/) is the bridge: a script that automates nothing, but walks the operator through each step and waits for confirmation.

| Stage | What exists | What the document becomes |
| --- | --- | --- |
| 1. Written | The procedure | The procedure |
| 2. Do-nothing script | A script that prints each step and waits for Enter (`Read-Host` in PowerShell) | The script, plus when to run it |
| 3. Partly automated | The easy steps replaced with code, one at a time | Prerequisites and the steps still done by hand |
| 4. Automated | A tool or scheduled job | A runbook for running and troubleshooting the tool |

At stage 4, the tool's own docs fall under the planned Automation script or tool module.

## Tools

- **The team's documentation platform:** use its owner and review-date fields if it has them, so stale procedures surface on their own.
- **Markdown in Git:** for procedures that live next to the code or configuration they operate on, so a change and its procedure update ship together.
- **PowerShell `-WhatIf` and `Read-Host`:** dry runs for destructive steps, and the building block for do-nothing scripts.
- **Ticket templates:** link the SOP from the ticket type that triggers it, and include its Records fields.
- **Save-Screenshot.ps1:** dated captures for GUI steps.

## Exemplars

- [Diátaxis: how-to guides](https://diataxis.fr/how-to-guides/): steal the rule that a how-to serves someone already doing the task, so it doesn't stop to teach.
- [Microsoft Writing Style Guide: step-by-step instructions](https://learn.microsoft.com/en-us/style-guide/procedures-instructions/writing-step-by-step-instructions): steal one action per step, with location before action.
- [GitLab runbooks](https://runbooks.gitlab.com/): steal one page per alert, named after the alert, grouped by service, built from a shared template.
- [Do-nothing scripting](https://blog.danslimmon.com/2019/07/15/do-nothing-scripting-the-key-to-gradual-automation/): steal the gradual path from document to automation.

## Checklist additions

- [ ] The title is a verb and an object
- [ ] The trigger, prerequisites, role and time estimate are stated
- [ ] Each step is one action, with an expected result after every state change
- [ ] Destructive steps carry a warning and a dry run
- [ ] Rollback, stop conditions and escalation are written
- [ ] No secrets, and internal identifiers are redacted if it leaves the team
- [ ] Someone other than the author has tested it, with the date recorded
- [ ] An owner and a review date are set

## Rubric adjustments

- **Replace Reproducibility with Executability:** a competent stranger completes the task from the document alone. This is the criterion that matters most.
- **Add Currency:** the last test postdates the last change to the system.
- **Lower Reasoning:** a procedure states what to do and links to the why; one line of reason beside a surprising step is enough.
- **Drop Reflection:** lessons go straight into fixes and the change history.
- **Weight Presentation higher:** an ambiguous step costs more here than in any other type.
