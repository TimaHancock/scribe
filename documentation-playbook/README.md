# Project Documentation Playbook

A generalist playbook for documenting projects, labs and writeups, for portfolio pieces and work documentation, with type modules for formats that need extra rules.

Started 2026-10-07. Exported from Claude Docs on 2026-11-02.

## How to use it

Run every project through one loop: frame it before you start, capture evidence while you work, then turn that record into a layered writeup. The playbook holds the rules that apply to every project, lab, or writeup. The other sections hold material you open when you need it.

| Section | Open it when |
| --- | --- |
| [Playbook](playbook/README.md) | You need the process, the rules, or the quality bar |
| [Templates](templates/README.md) | You start a phase and want the blank form |
| [Exemplar Library](exemplar-library.md) | You are writing in an unfamiliar format and want a model to copy |
| [Toolkit](toolkit.md) | You are choosing or standardizing tools |
| [Type Modules](type-modules/README.md) | A project type needs extra rules on top of the core |

Type modules may add or rename sections and add checks for their format. They never remove a core principle or the sanitization pass.

## Layout

```text
documentation-playbook/
  README.md                 this page
  playbook/                 the core process, one file per section
    01-core-principles.md
    02-the-documentation-lifecycle.md
    03-capture-system.md
    04-anatomy-of-a-strong-writeup.md
    05-writing-and-evidence-craft.md
    06-sanitization-and-ethics.md
    07-packaging-and-publishing.md
    08-work-documentation.md
    09-quality-bar.md
    sources.md
  templates/                blank forms, one per lifecycle phase
    01-kickoff-card.md
    02-running-log.md
    03-decision-record.md
    04-master-writeup.md
    05-short-forms.md
    06-retrospective-and-brag-doc-entry.md
  exemplar-library.md       public models to copy, by format
  toolkit.md                tools, by job
  type-modules/             extra rules per project type
    README.md               how modules work, the spec, the registry
    academic-assessment.md
    coding-project.md
    it-project.md
    runbook-or-sop.md
    technology-evaluation.md
```
