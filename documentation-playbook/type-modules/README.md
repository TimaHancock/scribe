# Type Modules

Type modules add format-specific rules on top of the core playbook without rewriting it. Each module gets its own file in this folder.

## How modules work

A module specializes the core playbook for one project type: it adds or renames sections, sets the evidence standard and adds checks. It never removes a core principle, the summary-first rule or the redaction pass.

- **Precedence.** Where a module and the core disagree, the module wins on structure and the core wins on principles and safety.
- **Adding one.** Create a file in this folder named `<type>.md`, paste the spec below, fill every field, then update its status in the registry.
- **Seeding it.** Read the seed exemplars listed in the registry first, then write the module from what they have in common.
- **Proving it.** Keep a module at Drafting until it has carried two real projects end to end, then mark it Ready.
- **Using it.** Name the module on each project's kickoff card, so the work follows its rules from day one.

## Module spec

Every module fills the same eleven fields, so modules stay comparable and easy to maintain.

```markdown
# Module: <project type>
Status: Planned | Drafting | Ready · Last reviewed: YYYY-MM-DD

## Covers
Which projects use this module, and which look similar but do not.

## Readers
The primary and secondary readers, and what each needs from the piece.

## Template changes
Sections added, renamed or cut relative to the master writeup, and why.

## Project directory
The full workspace tree for this type, marking folders added (new), renamed or dropped relative to the core layout.

## Capture specifics
What to log and save for this type that the core capture system misses.

## Evidence standard
What counts as proof here, e.g. flags, hashes, test runs, before-and-after metrics.

## Safety and rules
Platform, legal, contractual or data-handling rules specific to this type.

## Tools
Type-specific tools, each with the job it does.

## Exemplars
Two or three public pieces, each with the technique to steal.

## Checklist additions
Extra pre-publish checks for this type.

## Rubric adjustments
Criteria to add, drop or reweight.
```

## Module registry

Fourteen modules are listed, in suggested build order; reorder them as your projects change.

| Module | Covers | Seed exemplars | Status |
| --- | --- | --- | --- |
| Lab and CTF writeup | Hack The Box and similar boxes, CTF challenges, course labs | [0xdf](https://0xdf.gitlab.io/); [HTB publication rules](https://help.hackthebox.com/en/articles/5188925-streaming-writeups-walkthrough-guidelines) | Planned |
| Automation script or tool | PowerShell or Python tools, CLIs, scheduled jobs | [How I build a feature](https://simonwillison.net/2022/Jan/12/how-i-build-a-feature/); [Awesome README](https://github.com/matiassingers/awesome-readme) | Planned |
| Cloud and identity configuration | Tenant settings, access policies, configuration-as-code rollouts | [Nygard ADR](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions); [Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/) | Planned |
| Security assessment report | Pentests, vulnerability assessments, audits | [Public pentesting reports](https://github.com/juliocesarfort/public-pentesting-reports) | Planned |
| Infrastructure and homelab build | Lab networks, servers, containers, hardware | [Raspberry Pi PCIe Database](https://pipci.jeffgeerling.com/) | Planned |
| Software or product build | Web apps, SaaS tools, games, study tools | [Oxide RFD 1](https://rfd.shared.oxide.computer/rfd/0001); [Awesome README](https://github.com/matiassingers/awesome-readme) | Planned |
| Fleet rollout or change | One change applied across many systems or sites | [GitLab postmortem](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/), for its runbook lessons | Planned |
| Research deep-dive | Cryptography, protocol or vulnerability analysis | [Project Zero RCA template](https://googleprojectzero.github.io/0days-in-the-wild/0day-RCAs/template.html) | Planned |
| [Academic assessment](academic-assessment.md) | Graded course projects, capstones, certification labs | Your program's rubric and academic integrity policy | Drafting |
| Incident postmortem | Outages and security incidents | [Google SRE example](https://sre.google/sre-book/example-postmortem/); [Cloudflare 2019](https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/) | Planned |
| Investigation and detection | Threat hunts, DFIR cases, detection rules | [The DFIR Report](https://thedfirreport.com/2026/02/23/apache-activemq-exploit-leads-to-lockbit-ransomware/) | Planned |
| [Runbook or SOP](runbook-or-sop.md) | Operational how-to documents for a team | [Diátaxis: how-to guides](https://diataxis.fr/how-to-guides/) | Drafting |
| [IT project](it-project.md) | Migrations, deployments, policy rollouts, decommissions. Fleet rollout and Cloud and identity configuration extend it | [Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/); [GitLab change management](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/change-management/) | Drafting |
| [Technology evaluation](technology-evaluation.md) | Product, tool and approach selection, feasibility research, proofs of concept | [MADR](https://adr.github.io/madr/); [Rust RFC template](https://github.com/rust-lang/rfcs/blob/master/0000-template.md) | Drafting |

To build one, ask Claude to draft the module from its seed exemplars and the spec above, then test it on your next project of that type.
