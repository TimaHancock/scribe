# Anatomy of a strong writeup

A strong writeup answers four questions in order: what happened, why it mattered, how you did it, and what you learned. The [master template](../templates/04-master-writeup.md) fixes where each answer goes. It covers the same ground as NN/g's case-study checklist for hiring managers: problem, your role, how you reached the solution, challenges, impact and lessons ([NN/g](https://www.nngroup.com/articles/ux-design-portfolios/)).

### Section order

| Section | Must answer | OK to cut when |
| --- | --- | --- |
| Title | What did you achieve, specifically? | Never |
| Metadata | Date, status, time spent, your role, stack, skills shown, links | Never |
| Summary | Problem, approach, result with a number and one lesson, in 3 to 5 sentences; write it last | Never |
| Context and problem | Why it mattered, and to whom | A practice lab with no stakeholder; one line is enough |
| Goals and non-goals | What done meant, and what you chose not to do | Never; non-goals answer "why didn't you" before it is asked |
| Environment | What the reader must picture: diagram, components, versions | Pure research or analysis pieces |
| Approach and decisions | Options weighed, choice made, reasons | Never |
| Walkthrough | Each step's why, what and proof | Short forms (card, summary) |
| Results | Before and after with units; findings ranked by impact | Never |
| Challenges and dead ends | What broke, how you found it, what it cost | Never in a portfolio piece |
| Going further | What you explored after the goal was met | Time-boxed work with nothing extra |
| Lessons and next steps | What went well, what went wrong, where you got lucky, what comes next | Never |
| References and credits | Sources, tools, collaborators, AI assistance | Never |
| Appendix | Full configs, scripts, raw output, indicators, glossary | A linked repo already holds them |

Two of these sections come straight from public exemplars. 0xdf ends many Hack The Box writeups with a "Beyond Root" section that explains why an attack worked or shows another path ([0xdf](https://0xdf.gitlab.io/)). Google's example postmortem adds "Where we got lucky" to its lessons, so near misses get recorded too ([Google SRE](https://sre.google/sre-book/example-postmortem/)).

### The depth ladder

One project produces four layers, each linking to the next one down. Readers stop at the layer that answers their question.

| Layer | Length | Reader | Lives in |
| --- | --- | --- | --- |
| Card | 2 to 3 sentences plus links | Recruiter scanning a list | Portfolio index, resume, profile |
| Summary | One screen | Hiring manager deciding whether to read on | Top of the writeup |
| Writeup | As long as the evidence needs | Engineer judging your skill | Blog, portfolio site, wiki |
| Appendix or repo | No limit | Someone rerunning or auditing the work | Git repo, attachments |

Write the layers bottom-up and publish them top-down. The appendix and writeup come from your capture; the summary and card are distilled from the writeup.
