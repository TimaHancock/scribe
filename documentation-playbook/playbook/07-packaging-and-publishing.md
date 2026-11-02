# Packaging and publishing

Publish each project as linked layers, so a recruiter's quick scan and an engineer's deep read land on the same work.

### Choose the venue

| Venue | Best for | Watch for |
| --- | --- | --- |
| Git repo README | Code, scripts, tools, configs | Write for a stranger: what it is, why it exists, quickstart, screenshot |
| Personal site or blog | Narrative writeups and the portfolio index | Keep URLs stable; you own the domain and the archive |
| Dev.to or Hashnode | Reach before you have a site of your own | Keep a master copy you control |
| PDF report | Formal deliverables, work reports, applications | Hard to link by section; also publish HTML when it is public |
| Internal wiki or docs repo | Work documentation | An owner and a review date on every page |
| Video or GIF | Interaction, UI flows, demos | Never the only format; pair it with text for search and accessibility |

### The portfolio index

Keep one page listing every project as a card: title, one-line outcome, date, 3 to 5 skill tags, and links to the writeup, repo and demo. Pin your strongest 3 to 5 pieces at the top; NN/g advises 3 to 5 detailed case studies over many thin ones ([NN/g](https://www.nngroup.com/articles/ux-design-portfolios/)). Tag cards with the skills named in the job descriptions you target.

### Cross-link every layer

- The resume bullet links to the card or writeup; the writeup links to the repo; the repo README links back.
- Use one project name and slug everywhere, so search and memory find the same thing.
- Treat the writeup as part of the project. The Cloud Resume Challenge makes a blog post about what you learned its final required step, linked from the resume itself ([Cloud Resume Challenge](https://cloudresumechallenge.dev/docs/the-challenge/aws/)).

### Versions and dates

- Show "published" and "last verified" dates at the top of every piece.
- Log changes at the bottom, one dated line each.
- When a piece goes stale, say so at the top and link its replacement instead of deleting it. Oxide's RFD process keeps abandoned ideas visible as a state ([Oxide RFD 1](https://rfd.shared.oxide.computer/rfd/0001)), and ADRs mark reversed decisions superseded.

Site tooling is changing: Material for MkDocs, a popular documentation theme, reaches end of life on November 5, 2026, and its maintainers point new projects to Zensical ([release notes](https://github.com/squidfunk/mkdocs-material/releases)). Current picks are in [Toolkit](../toolkit.md).
