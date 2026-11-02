# Core principles

Ten rules sit under every template and type module. A module can add rules but never drop these.

1. **Write for a named reader, bottom line first.** Name the reader before writing, then open with the result, not the backstory. Hiring managers rarely read a portfolio word for word, so the first screen must carry the point ([NN/g](https://www.nngroup.com/articles/ux-design-portfolios/)).
2. **Capture while you work; write afterward.** Memory drops the exact errors, timings and dead ends that make a writeup credible. Log each entry as it happens, dated, with enough detail to redo the step ([Schnell 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4565690/)).
3. **Show the reasoning.** Record the options you weighed, what each cost and why you chose one. Google's design-doc practice treats "alternatives considered" as one of the most important sections ([Ubl 2020](https://www.industrialempathy.com/posts/design-docs-at-google/)).
4. **Put evidence beside every claim.** A result needs a screenshot, log line, output, metric or link next to it. Readers should never have to take your word for something they could see.
5. **Make it reproducible.** Record versions, environment, exact commands, inputs and configs, and keep the raw data behind every figure. Keep scripts under version control so each result ties to the code that produced it ([Schnell 2015](https://pmc.ncbi.nlm.nih.gov/articles/PMC4565690/)).
6. **Keep the dead ends.** Strike failed attempts through; never delete them. In a portfolio, the debugging story often shows more skill than the happy path.
7. **Give each document one job.** Diátaxis separates tutorials, how-to guides, reference and explanation because each serves a different need ([Diátaxis](https://diataxis.fr/)). A writeup can hold several, as long as each section has one job.
8. **Sanitize before anything leaves your machine.** Treat every capture as sensitive until reviewed. Redact with opaque boxes only, because pixelation and blur can be reversed ([Bishop Fox](https://bishopfox.com/blog/unredacter-tool-never-pixelation)).
9. **Blame systems, credit people exactly.** Describe what the system allowed, not who slipped, as blameless postmortems do ([Google SRE](https://sre.google/sre-book/postmortem-culture/)). State precisely what you did and what the team did.
10. **Ship it, date it, keep it current.** Add "write about it" to your definition of done ([Willison](https://simonwillison.net/2022/Nov/6/what-to-blog-about/)). Date every piece, because wrong documentation is worse than none ([Write the Docs](https://www.writethedocs.org/guide/writing/docs-principles/)).
