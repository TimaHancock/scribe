# Exemplar Library

Real public pieces that model a technique worth copying. Read two or three in the target format before writing your own.

## Incidents and postmortems

Postmortems model how to explain a failure honestly, in time order, with fixes the reader can track.

| Piece | What it is | Technique to steal |
| --- | --- | --- |
| [Cloudflare: Details of the Cloudflare outage on July 2, 2019](https://blog.cloudflare.com/details-of-the-cloudflare-outage-on-july-2-2019/) | John Graham-Cumming's account of a 27-minute global outage caused by one firewall rule's regular expression | All times in UTC; eleven contributing failures listed instead of one root cause; each fix marked done or given a date; the regex deep dive moved to an appendix |
| [GitLab: Postmortem of database outage of January 31](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/) | GitLab's 2017 account of an accidental production database deletion and a restore that took over 18 hours | Notes kept in a public document and a live stream during recovery; 5 Whys run on two separate problems; every improvement linked to a tracked issue; names redacted in future records |
| [Google SRE: Example Postmortem](https://sre.google/sre-book/example-postmortem/) | A model postmortem from the SRE book, built around a fictional search outage | Metadata header with status; action items in a table with type, owner and done or to-do; a "Where we got lucky" list for near misses |

## Security writeups and reports

Security writing is judged on whether a defender or another tester can reuse it, not only on whether the attack worked.

| Piece | What it is | Technique to steal |
| --- | --- | --- |
| [0xdf hacks stuff](https://0xdf.gitlab.io/) | A long-running blog of Hack The Box and CTF writeups | A one-paragraph summary of the whole path up top; technique tags on every post; a "Beyond Root" section on why the attack worked or what else was possible |
| [The DFIR Report: Apache ActiveMQ Exploit Leads to LockBit Ransomware](https://thedfirreport.com/2026/02/23/apache-activemq-exploit-leads-to-lockbit-ransomware/) | Intrusion analysis of a real case, published February 2026 | Key takeaways first; sections follow the attack phases from initial access to impact; a timeline, diamond model, indicators, Sigma and YARA detections and an ATT&CK map make it reusable |
| [Project Zero: 0-day Root Cause Analysis template](https://googleprojectzero.github.io/0days-in-the-wild/0day-RCAs/template.html) | Google Project Zero's fixed template for analyzing exploited 0-days | The same question set every time (basics, code, vulnerability, exploit, next steps), ending in variant analysis and ideas to kill the whole bug class |
| [Public penetration testing reports](https://github.com/juliocesarfort/public-pentesting-reports) | A curated collection of public pentest and audit reports from dozens of firms, including Cure53, NCC Group and Trail of Bits | Read three reports from different firms and compare how each presents findings, severity and fixes to executives and engineers |

## Design and decision records

These formats capture the reasoning that walkthroughs leave out: what was considered, what was chosen, and what it cost.

| Piece | What it is | Technique to steal |
| --- | --- | --- |
| [Michael Nygard: Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) | The 2011 post that defined the architecture decision record (ADR) | One decision per short file, numbered and never reused; title, context, decision, status, consequences; reversed decisions stay, marked superseded |
| [Malte Ubl: Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/) | How Google engineers write design docs, published 2020 | Goals and non-goals; alternatives considered, with trade-offs; a 1 to 3 page "mini design doc" for small changes |
| [Oxide RFD 1: Requests for Discussion](https://rfd.shared.oxide.computer/rfd/0001) | Oxide Computer's public process for written proposals | Explicit states from prediscussion to committed or abandoned; each RFD records the viable options, the reasoning with data, and the determination |

## Learning in public and lab notebooks

These show how to make capture a habit, so the writeup is mostly assembled before the work ends.

| Piece | What it is | Technique to steal |
| --- | --- | --- |
| [Simon Willison: How I build a feature](https://simonwillison.net/2022/Jan/12/how-i-build-a-feature/) | His issue-first development process, published 2022 | Every task gets an issue used as a running notebook; commits reference the issue; code, tests and docs ship in one commit |
| [Simon Willison: What to blog about](https://simonwillison.net/2022/Nov/6/what-to-blog-about/) | His case for short TILs and project write-ups, published 2022 | Lower the bar with "Today I Learned" notes; make writing about a project part of done; always include a screenshot or GIF, because projects stop working |
| [Schnell: Ten Simple Rules for a Computational Biologist's Laboratory Notebook](https://pmc.ncbi.nlm.nih.gov/articles/PMC4565690/) | A 2015 PLoS Computational Biology editorial on notebook practice | Date every entry with a subject; record how each result was produced; never erase mistakes; keep a table of contents |

## Builds, labs and project logs

Build documentation works best as structured, repeatable records that a reader can compare at a glance.

| Piece | What it is | Technique to steal |
| --- | --- | --- |
| [Jeff Geerling: Raspberry Pi PCIe Database](https://pipci.jeffgeerling.com/) | A compatibility database of tested PCIe cards, built from a [public GitHub repo](https://github.com/geerlingguy/raspberry-pi-pcie-devices) | One page per device from a shared card template; a status per platform (full, partial, none, currently testing) in scannable tables; corrections arrive as pull requests |
| [The Cloud Resume Challenge](https://cloudresumechallenge.dev/docs/the-challenge/aws/) | A portfolio project: a cloud-hosted resume with infrastructure as code, CI/CD and tests | The final required step is a short blog post on what you learned, linked from the resume itself |

## Repos, READMEs and career documents

These are the front doors: the pages a stranger reads first, and the record you mine for portfolio pieces.

| Piece | What it is | Technique to steal |
| --- | --- | --- |
| [Awesome README](https://github.com/matiassingers/awesome-readme) | A curated list of well-made READMEs, with guides and GIF-capture tools | Study three READMEs in your project's category; the common elements are a clear description, a screenshot or GIF, quick install steps and a table of contents |
| [Make a README](https://www.makeareadme.com/) | A README guide with an editable template, listed in Awesome README | Start from the template instead of a blank page |
| [Julia Evans: Get your work recognized: write a brag document](https://jvns.ca/blog/brag-documents/) | A template for tracking your own accomplishments, published 2019 | Sections for projects, collaboration, design and documentation, and learning; record impact, then revisit months later for actual results |
| [Nielsen Norman Group: 5 Steps to Creating a UX-Design Portfolio](https://www.nngroup.com/articles/ux-design-portfolios/) | Portfolio guidance based on a survey of 204 hiring professionals, published 2019 | A seven-part case study: problem, your role, how you reached the solution, how it solved the problem, challenges, impact, lessons |

NN/g writes for designers, but its case-study structure transfers to any technical portfolio.
