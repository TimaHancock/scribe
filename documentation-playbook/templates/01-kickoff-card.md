# Kickoff card

Fill this in before you start. It becomes the top of the project README and the seed of the final summary.

The block between the `---` lines is frontmatter: Obsidian shows it as properties, and the projects dashboard ([projects.base](projects.base)) lists every README with `type: project`. Move `status` through planning, active, paused and done as the work goes. `New-Project.ps1` fills in the dates and module, and Scribe sets `updated` on each day you log.

```markdown
---
type: project
status: planning
module: <none, or module name>
started: YYYY-MM-DD
updated: YYYY-MM-DD
---
# <Outcome-oriented title, e.g. "Cut report prep from 2 hours to 10 minutes">

## Goal
One sentence: what will be true when this is done?

## Reader
Who will read the writeup, and what should they be able to decide or do afterward?

## Done means
- A success criterion with a number or an observable state
- ...

## Scope
In: ...
Out (non-goals): ... and why

## Story question
The one question the writeup will answer, e.g. "Can X be done with only Y?"

## Baseline
The current state and how you measured it. Save before-numbers and screenshots now.

## Constraints and permissions
Authorization, data-handling rules, platform rules, NDA, time box.
```
