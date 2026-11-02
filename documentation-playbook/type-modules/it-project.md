# Module: IT project

Status: Drafting · Last reviewed: 2026-10-19

Use this module for work that changes an environment over weeks and ends with someone else running the result. It is one of three IT work modules: projects change things, procedures repeat things ([Runbook or SOP](runbook-or-sop.md)), and evaluations decide things ([Technology evaluation](technology-evaluation.md)). One piece of work often uses all three: an evaluation picks the tool, the project deploys it, and the project hands over runbooks.

## Covers and readers

**Covers:** migrations, new service deployments, tenant-wide policy rollouts, decommissions, consolidations, and client onboarding projects.

**Doesn't cover:** a task the team will repeat (Runbook or SOP), choosing between products or approaches (Technology evaluation), or the deep detail of a single fleet change or tenant configuration. The planned Fleet rollout and Cloud and identity configuration modules will extend this one for those.

| Reader | What they need | Where they find it |
| --- | --- | --- |
| Approver or manager | What changes, the risk, when, and how to undo it | Change records |
| Team inheriting it | How it works now and how to support it | Handover pack |
| Client or stakeholder | What they get, any downtime, and when | Status updates and closeout summary |
| Auditor or future you | Why each choice was made, and what changed when | Decision log, change IDs |
| Portfolio reader | The problem, the scale, your decisions, the results | Anonymized case study |

## Template changes

One running log feeds five documents. Write each when its phase arrives, not at the end.

1. **Project brief** (one page, replaces the kickoff card): problem, scope in and out, measurable success criteria, stakeholders, constraints, top risks, target dates. Get it approved before work starts.
2. **Decision log:** one short record per choice someone could question later, in [Nygard's ADR](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) shape: context, decision, consequences, status. Superseded decisions stay, marked as superseded.
3. **Change records:** one per production change. What changes and why, systems and users affected, criticality, pre-checks, steps, validation, rollback plan and the trigger to use it, communications, approver, window.
4. **Handover pack (as-built):** how the system works now. Diagram, configuration summary, where things live, owners, monitoring and alerts, linked runbooks, known issues, and vault references for credentials.
5. **Closeout summary:** results against each success criterion, what changed, lessons. This becomes the source for the portfolio case study.

### Change criticality

Use your organization's change process if it has one. If not, scale the paperwork to the risk with this default, adapted from [GitLab's change management levels](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/change-management/):

| Level | Meaning | Example | Required before the change |
| --- | --- | --- | --- |
| C1 | Downtime expected, or every user affected | Conditional Access change scoped to all users | Written plan, peer review, approval, advance notice to users, rehearsed rollback, someone watching afterward |
| C2 | Elevated risk, no downtime expected | New policy rolled out to a pilot group | Written plan, peer review, approval, rollback plan |
| C3 | Low risk, but manual or complex | Manual cleanup of stale accounts | Change record and a second reviewer |
| C4 | Routine or automated | Scheduled patching through an existing pipeline | Logged for visibility only |

After a C1 or C2 change, leave handoff notes for whoever is on call: the change's state, anything silenced, and what to watch.

## Project directory

The core layout, with folders for change records, communications, before and after state, and the handover pack. (new) marks an addition.

```text
YYYY-MM-project-slug/
  README.md          project brief now, closeout summary later
  log.md             running log; tags CHANGE, COMMS, SCOPE, APPROVAL
  decisions/         NNN-slug.md, ADR shape; superseded records stay
  changes/           (new) one record per production change
    CHG-<ticket>_<slug>.md
  comms/             (new) stakeholder notices and status updates, dated
  evidence/
    before/          (new) baseline exports and counts from Discover
    after/           (new) the same exports after each change
      wave-1/
      wave-2/
    screenshots/     settings with no export; untouched originals
    terminal/        transcripts from change windows
    exports/         other query results and raw data
  scripts/           validation queries and anything run more than once
  diagrams/          current-state and target-state sources (.drawio)
  handover/          (new) the as-built pack, started in Design
    as-built.md
    runbooks/        drafts until they move to the team's platform
  drafts/            closeout and case-study drafts
  publish/           the anonymized case study only
```

- **Systems of record win.** `changes/` and `handover/` are working copies. The ticketing tool holds the official change record, and the team's documentation platform holds the final handover pack. Link to both from README.md, and move the final versions there at Hand over.
- **Config-as-code stays in its repo.** Don't copy configuration into this folder. Record commit or pull request links in the log and in each change record.
- **Name before and after exports identically**, such as `ca-policies.json` in both, so a plain diff compares them.

## Capture specifics and evidence standard

Export state; don't describe it. A configuration export or query result taken before and after is worth more than any paragraph about what changed.

Add these to the core capture system:

- **Baseline before you touch anything:** configuration exports, object counts, screenshots of settings with no export. Save them under `evidence/before/`.
- **After state:** the same exports and queries, under `evidence/after/`, so the two can be diffed.
- **Log tags:** CHANGE for each change ID or ticket number, COMMS for each stakeholder message with its date, SCOPE for anything added or cut, and APPROVAL with a link to where it was granted.
- **Window notes:** start and end times, anything unexpected, and whether the rollback trigger came close.
- **Config-as-code:** if the configuration lives in a repo, the commit diff is the evidence. Link the commit or pull request instead of re-capturing it.

| Claim | What proves it |
| --- | --- |
| "Applied to all 4,000 users" | Count query output before and after, with the query |
| "No user impact" | Ticket volume and sign-in or error logs across the window, compared with a normal week |
| "Matches the design" | Configuration export diffed against the desired state |
| "Rollback works" | A logged rollback in the pilot or a test environment |
| "Faster" or "cheaper" | The metric before and after, with dates and how it was measured |

## Safety and rules

Work documentation belongs to your employer or client. These rules sit on top of the core redaction pass.

- **Check before you write publicly.** MSP client agreements, NDAs and government contracts can forbid describing the work at all, not just naming the client. Government work may also carry data-handling rules, such as for controlled unclassified information. Get permission, or don't publish.
- **AI tools follow your employer's rules.** If only redacted data may go into AI tools, redact logs, exports and screenshots before pasting them, every time.
- **Anonymize the portfolio version fully.** Strip tenant and client names, domains, user names and UPNs, internal hostnames, IP ranges, ticket numbers and tenant IDs. Round headcounts and costs ("about 4,000 users" is fine; a client's exact license spend isn't).
- **Credentials stay in the vault.** Docs reference the vault entry name, never the secret, key or connection string. Run secret scanning on any repo that holds project docs.
- **No undocumented changes.** Don't record a change as done before it's approved. If an emergency change happens, write its change record afterward, the same day.
- **Screenshots leak.** Crop out tenant IDs, user names, IP addresses and browser tabs before saving, not just before publishing.

## Project lifecycle

Each phase ends with a document someone else can check. Start the handover pack in Design, not at the end.

| Phase | Document it produces | Done when |
| --- | --- | --- |
| 1. Initiate | Project brief | The brief is approved |
| 2. Discover | Baseline exports, inventory, dependency list | Current state is captured and no unknown dependencies remain |
| 3. Design | Design doc, first decision records, handover pack started | A peer has reviewed the design, including alternatives considered |
| 4. Pilot | Change record, pilot results | A go or no-go is recorded against the success criteria |
| 5. Roll out | One change record per wave, validation per wave | Every wave is validated, or rolled back and logged |
| 6. Hand over | Finished handover pack, runbooks, training notes | The named support owner accepts it in writing |
| 7. Close | Closeout summary, portfolio case study draft | Results are reported against every success criterion |

If a tool or vendor still has to be chosen in Discover, run a Technology evaluation and file its decision record in the decision log. In Hand over, use this test: if the service desk would call you about it, it needs a runbook.

## Tools

- **Ticketing or PSA:** the source of change IDs, approvals and the ticket-volume evidence.
- **The team's documentation platform** (IT Glue, Hudu, Confluence, SharePoint or similar): the handover pack lives there, not in your personal notes.
- **Configuration exports:** M365DSC, Graph or PowerShell `Get-*` output to files, for before and after state.
- **Git:** configuration-as-code and diffs; pre-commit secret scanning on any repo that holds docs.
- **diagrams.net:** architecture and before-and-after diagrams for the handover pack and case study.
- **Save-Screenshot.ps1:** timestamped evidence for settings that have no export.

## Exemplars

- [Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/): steal goals and non-goals, and the alternatives-considered section.
- [Nygard: Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions): steal the short, numbered decision record that is never deleted, only superseded.
- [GitLab change management](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/change-management/): steal criticality levels that scale the review, and handoff notes to on-call after a change.

## Checklist additions

- [ ] Every success criterion has a measured result
- [ ] Every production change has a change ID, an approver and a rollback plan
- [ ] Before and after evidence exists for each claim in the closeout
- [ ] The decision log is current, with superseded decisions marked
- [ ] A named owner has accepted the handover pack
- [ ] Runbooks exist for everything the service desk will be asked about
- [ ] The portfolio version is permitted and fully anonymized

## Rubric adjustments

- **Add Operability:** could someone else run and support the result tomorrow, from the handover pack alone?
- **Add Traceability:** each change links to its ticket, approval and evidence.
- **Reword Reproducibility as Repeatability:** a reader can't redo a production migration, but the team should be able to repeat the method in another environment.
- **Weight Results higher:** before and after measurements against the success criteria carry the case study.
