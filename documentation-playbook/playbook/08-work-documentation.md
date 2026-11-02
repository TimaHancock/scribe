# Work documentation

Work documentation serves operators, auditors and the next owner first, and your portfolio second. Write it for the job, then mine it for portfolio material with permission.

### Pick the document type

| Type | Answers | Diátaxis mode | Model to follow |
| --- | --- | --- | --- |
| Runbook or SOP | How do I do this safely, step by step? | How-to | Numbered steps, each with expected output |
| Design doc or RFC | What are we building, and why this way? | Explanation | [Design Docs at Google](https://www.industrialempathy.com/posts/design-docs-at-google/), [Oxide RFD 1](https://rfd.shared.oxide.computer/rfd/0001) |
| Decision record | Why did we choose this? | Explanation | [Nygard ADR](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) |
| Change record | What changed, when, by whom, and how do we roll back? | Reference | Your change-management system |
| Postmortem | What happened, what it cost, why, and what we fixed | Explanation and reference | [Google SRE example postmortem](https://sre.google/sre-book/example-postmortem/) |
| Configuration reference | What is the current state? | Reference | Exported configuration kept as code |
| Handoff or closeout | What does the next owner need? | Reference and how-to | Owner, open issues, where everything lives |
| Client report | What did you find, and what should they do? | Explanation | [Public pentesting reports](https://github.com/juliocesarfort/public-pentesting-reports) |

### Rules for work docs

- **Every page has an owner, a last-reviewed date and a review cadence.** Pages without owners rot quietly.
- **Write runbooks for a stressed reader at 2 a.m.:** numbered, copyable, with the expected output after each step. In GitLab's 2017 database outage, a replication behavior was missing from the runbooks and nobody owned testing the backups that failed silently ([GitLab postmortem](https://about.gitlab.com/blog/postmortem-of-database-outage-of-january-31/)).
- **Live in the system of record.** Store docs where the team already looks, and link them from the ticket or change.
- **Stay blameless and private.** Google's postmortems never include information that could identify an end user ([Google SRE](https://sre.google/sre-book/postmortem-culture/)).

### The brag document

Julia Evans recommends a running "brag document" of what you did and why it mattered ([Evans 2019](https://jvns.ca/blog/brag-documents/)). Her template covers projects (your contribution and its impact), collaboration and mentorship, design and documentation, and what you learned. Update it every couple of weeks or in one sitting before each review, then return months later to record actual results.

The brag document becomes the index you pick portfolio pieces from.

### From work to portfolio

1. Get written permission, and check your NDA or contract.
2. Abstract the story to the problem class, your method and the result, not the client.
3. Rebuild the scenario in a lab with fictional data when you need real screenshots. NN/g also suggests showing process artifacts and making designs generic for NDA work ([NN/g](https://www.nngroup.com/articles/ux-design-portfolios/)).
4. Use ratios or ranges when exact figures would identify the client, such as "cut triage time by about half".
5. Run the full redaction pass from [Sanitization and ethics](#mk5nd0p8v12.12167).
