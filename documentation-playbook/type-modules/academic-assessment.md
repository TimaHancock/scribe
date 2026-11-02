# Module: Academic assessment

Status: Drafting · Last reviewed: 2026-10-16

A school project produces two documents from one capture: the graded submission, written to the rubric for an evaluator, and a portfolio piece written later for a hiring reader. This module covers both, from a single task to a degree capstone.

## Covers and readers

**Covers:** any graded school work: performance assessments, written tasks, labs, coding projects, case-study analyses, presentations and capstones. It does not cover certification exams or study notes; those produce no deliverable to document.

| Reader | When | Needs |
| --- | --- | --- |
| Evaluator | At submission | Every rubric row found fast, at the depth its verb asks for, with the required evidence |
| Portfolio reader | After grading | The problem, your decisions and the result, without the rubric scaffolding |
| Future you | Revisions and later courses | What you submitted, what came back, and why |

Write for the evaluator first. A submission that is clear to an engineer but hard to score against the rubric still comes back for revision.

## Template changes

### Kickoff card additions

Add these fields to the core kickoff card before reading anything else about the task.

```markdown
## Assessment
Course and task code: <e.g. NET101 Task 1> · Attempt: 1
Rubric version or date: <from the task page>
Due or target date: YYYY-MM-DD · Evaluator turnaround: <typical days>
Submission format: <file types, length limits, required file names>
Required artifacts: <screenshots, video, repo link, slides>
Citation style: <APA 7, or none required>
AI-use rule: <what the school allows, and what it requires you to disclose>
Publishing rule: <may this work, or parts of it, appear in a portfolio?>
```

### Rubric traceability matrix

Build this before writing. Each rubric row becomes one line, and the submission isn't done until every line reads Done.

| Rubric row | Verb and threshold | Heading in submission | Evidence and location | Status |
| --- | --- | --- | --- | --- |
| A1 | Identify two laws | A1. Applicable laws | Citations 1 and 2 | Done |
| A2 | Explain each risk rating | A2. Risk analysis | Table 2, Figure 1 | Drafting |
| B | Justify the recommendation | B. Recommendation | Sources 4–6 | Not started |

The verb sets the depth. "Identify" means name it; "describe" adds what it is; "explain" and "discuss" add how or why; "analyze" breaks it into parts and their relationships; "justify" or "evaluate" defend a choice against alternatives. Work to the verb in the rubric's passing column, not to how much you know.

### Graded submission skeleton

The submission follows the rubric, not the master writeup.

```markdown
# <Task title as given> · <Course code> · <Your name or ID, per instructions>

## A1. <Rubric row, in the rubric's own words>
The answer first, at the depth the verb asks for, then evidence and citation.

## A2. ...

## References
In the required style; every entry cited in the text, every in-text citation listed here.

## Appendix (only if allowed)
Screenshots, code listings, raw output, each labeled with the rubric row it supports.
```

- Use the rubric's row codes as headings, in rubric order. Evaluators score row by row.
- Leave dead ends, tool tangents and "what I learned" out unless a row asks for reflection. They go in your log and the portfolio version.
- State assumptions the scenario leaves open. For example: "The case study does not name a backup schedule, so this analysis assumes daily backups."

### Portfolio version

After the grade posts, rewrite from the master writeup template, not from the submission.

- Replace rubric codes with the core sections: problem, goals, approach and decisions, results, lessons.
- Open the metadata row with the context: "Completed for \<course> at \<school>, graded YYYY-MM."
- Keep the analysis, diagrams and decisions; drop the task prompt and rubric wording.
- Add what the rubric didn't ask for: the dead ends, what you would do with real constraints, and what you would change now.

## Project directory

The core layout, with folders for the task as given, sources, each submitted attempt and evaluator feedback. (new) marks an addition.

```text
YYYY-MM-<course>-<task>/
  README.md          kickoff card: course, task, rubric version, due date, rules
  log.md             running log; tags RETURN and AI
  task/              (new) private snapshot of the prompt, rubric and case files
  matrix.md          (new) rubric traceability matrix
  sources/           (new) citations log, plus saved copies of key sources
    citations.md
  decisions/
  evidence/
    screenshots/     required captures, with the details the task demands
    terminal/
    exports/
  scripts/
  diagrams/
  drafts/            graded submission drafts
  submitted/         (new) exact files sent, never edited afterward
    <course>_<task>_attempt-1.docx
  feedback/          (new) evaluator comments per attempt, kept private
    attempt-1.md
  publish/           portfolio version, after grading and only if permitted
```

**Capstone variant:** one root for the whole capstone, one folder per task, and shared logs and evidence so later tasks can cite earlier captures.

```text
YYYY-MM-<course>-capstone/
  README.md          capstone overview, task list, link to the official requirements
  log.md             one log across every task
  sources/           one citations log for the whole capstone
  decisions/
  evidence/          shared by all tasks
  task-1-proposal/
    task/
    matrix.md
    drafts/
    submitted/
    feedback/
  task-2-<name>/
  task-3-<name>/
  publish/
```

- **`task/` and `feedback/` never reach `publish/`.** They hold the school's materials and evaluator comments.
- **Use Zotero for citations?** Keep the collection there and put only its name and an export in `sources/`.
- **Don't edit files in `submitted/`.** A revision is a new attempt file, so you can always show exactly what an evaluator saw.

## Capture specifics and evidence standard

### Extra things to capture

- **The task as it stood.** Save a private copy of the task prompt, rubric and any case-study files the day you start, with the version or date. Rubrics change between terms, and revisions are judged against the version you were given.
- **A citations log.** Record each source the moment it shapes your thinking: title, author or organization, date, URL and access date. Reconstructing citations at the end is slow and error-prone. Prefer primary sources, such as NIST, IETF RFCs, vendor documentation and statute text, over blogs and mirrors.
- **A revision log.** For each evaluator return, log the date, rubric row, the comment in full (privately), your diagnosis and the fix. Tag these lines `RETURN` in the running log.
- **An AI-use log.** If you use AI assistance, log what you asked for, what you kept and what you verified. Tag these lines `AI`. This makes any required disclosure accurate and quick.
- **Required screenshots, with the required details.** If the task demands visible timestamps, usernames or hostnames, capture them in frame at the time; they are hard to recreate. The Save-Screenshot tool names files with the capture time automatically.
- **The submitted files.** Keep the exact files you submitted for each attempt, named `<course>_<task>_attempt-N.<ext>`.

### Evidence standard

| Claim type | Counts as proof |
| --- | --- |
| A fact about a law, standard or technology | A citation to the primary source, in the required style |
| Something you built or configured | A screenshot showing the required details, or code in the repo with commit history |
| A rating or judgment | The scale or framework it comes from, cited, plus your reasoning tied to scenario facts |
| A recommendation | The alternatives considered and why this one fits the scenario's constraints |
| A result | Output, a test run or a before-and-after measurement |

Tie every judgment to a specific fact from the scenario. Generic best-practice statements that ignore the scenario are a common reason a row comes back.

## Safety and rules

Your school's policies override this playbook. Read them once per program and note the rules on the kickoff card.

- **Original work.** The analysis, writing and code you submit must be yours. Use AI assistance only as the school's policy allows, and disclose it the way the policy requires.
- **Reusing your own work.** Submitting text from an earlier course or attempt can count as self-plagiarism. Check the policy before you reuse, and cite yourself if it's allowed.
- **Similarity checks.** Many schools run submissions through similarity software. Quote and cite anything taken from a source, even a single sentence.
- **Course materials are not yours to publish.** Task prompts, rubrics, case studies and lab instructions belong to the school. Never post them, even paraphrased closely, and never post completed answers to a task other students still take.
- **Publish after grading, and only what's allowed.** Wait until the grade posts and confirm the publishing rule. When in doubt, publish the problem class, your approach and your own artifacts rather than the graded document itself.
- **No real employer data.** Keep work data out of school projects unless your employer approves it in writing. Use the case study or a fictional organization instead.
- **Lab environments.** Never expose school lab credentials, VM addresses or access links in screenshots or repos you make public.

## Capstone track

A capstone is several graded tasks run as one project. Use one project folder and one running log across all of them, so each later task can cite evidence captured in an earlier one.

| Phase | What you produce | Documentation focus |
| --- | --- | --- |
| 1. Topic or proposal | Problem statement, scope, approval form | Scope boundaries and success criteria on the kickoff card; save the approval |
| 2. Plan and design | Requirements, design, timeline, risks | Decision records for every design choice an evaluator could question |
| 3. Build or implementation | The working product, lab or study | Timestamped screenshots per requirement; log every deviation from the plan |
| 4. Evaluation | Test results, metrics against the success criteria | Before and after evidence that ties back to phase 1 criteria |
| 5. Final report or presentation | The graded write-up, video or defense | Traceability matrix complete; every claim points at evidence from phases 3 and 4 |
| 6. Revisions | Resubmissions after evaluator feedback | RETURN entries in the revision log, one per returned row |

Plan around evaluator turnaround. Budget several business days per submission and at least one revision cycle per task, and don't start a dependent task's write-up on an unapproved earlier task.

### Your capstone's requirements

Copy your program's official capstone requirements into the capstone README before you start: the task list, rubric rows, required artifacts, length or format limits and approval steps. Then map each rubric row into the traceability matrix above.

## Tools

- **Zotero** (free): captures sources from the browser and formats references in APA or your required style.
- **Save-Screenshot.ps1**: timestamped, described screenshots with PROOF lines in the log.
- **Traceability matrix**: a spreadsheet or the table above, kept beside the draft.
- **Git**: version history for code and drafts, which also shows the work is yours if a similarity flag is ever questioned.
- **Your school's writing center and similarity checker**, if it offers a pre-submission check.

## Exemplars

- [NN/g: UX portfolio advice for students](https://www.nngroup.com/articles/ux-design-portfolios/): turning coursework into case studies that show process.
- [APA Style](https://apastyle.apa.org/): reference formats and student paper guidance.
- Your own graded work: once a task passes, keep the evaluator comments next to the submission. They are the most accurate exemplar of what your program accepts.

## Checklist additions

Add these to the core pre-publish checklist for any graded submission:

- [ ] Every rubric row has a heading and evidence in the matrix
- [ ] Each response meets its verb's depth (discuss, not just identify)
- [ ] Format, length and file type limits met
- [ ] In-text citations and a references list in the required style
- [ ] Required screenshot details visible (timestamp, hostname, user, or whatever the task specifies)
- [ ] AI use disclosed as policy requires
- [ ] Files named `<course>_<task>_attempt-N.<ext>`
- [ ] Before publishing anything: grade posted, publishing rule checked, course materials removed

## Rubric adjustments

- **Add Rubric coverage:** every row addressed at the required depth, with traceable evidence. For graded submissions this outweighs every other criterion.
- **Reproducibility:** lower its weight for written analyses with no build. Keep it at full weight for technical tasks with a lab or code component.
- **Presentation:** judge the graded version against the evaluator's needs, and the portfolio version against the core rubric.
