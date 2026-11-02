# Writing and evidence craft

Clear writeups follow a handful of mechanical rules. Apply them while drafting, then check them in review.

### Sentences and structure

- **Bottom line first** at every level: the document, each section, each paragraph.
- **Headings that state findings,** such as "A port mismatch caused the 502" rather than "Issue".
- **Short paragraphs** of one idea and three sentences or fewer; active voice; present tense for procedures, past tense for what happened.
- **Acronyms defined** at first use, plus a glossary for acronym-heavy topics.
- **Descriptive link text** that names the destination, never "click here" ([Write the Docs](https://www.writethedocs.org/guide/writing/docs-principles/)).
- **One style guide,** applied consistently. The [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) and the [Google developer documentation style guide](https://developers.google.com/style) are both free.

### Why, what, proof

Every walkthrough step carries three parts: why you did it, exactly what you did, and the evidence that it worked. A reader who skims only the "why" lines should still follow the story.

```markdown
### 3. Confirm which port the app listens on
**Why:** The proxy's connections were refused, so the upstream port was suspect.
**What:**

    docker exec app ss -tlnp

**Proof:** The output lists a listener on port 3000, not 8080 (log, 14:47).
```

### Code and commands

- Code is text, never a screenshot of text.
- Separate the command from its output; show the prompt only when the user or host matters.
- Mark placeholders one way, such as `<TENANT_ID>`, and say what goes there.
- Trim long output with a marked gap (`...`) and keep the full version in the appendix.
- State OS, tool and module versions once, in the metadata.

### Screenshots and visuals

- Crop to the region that matters, keeping enough context to orient the reader.
- Mark the spot with a box or numbered callout, and refer to the number in the text.
- Caption each figure with what to notice, not what it is.
- Pick the form by job: diagrams for structure and flow, short GIFs or recordings for interaction, charts for before-and-after numbers.
- Write alt text that conveys the information in the image ([W3C alt decision tree](https://www.w3.org/WAI/tutorials/images/decision-tree/)).
- Screenshot anything that runs. Projects stop working, but the picture survives ([Willison](https://simonwillison.net/2022/Nov/6/what-to-blog-about/)).

### Results and impact

- Quantify with before, after and the unit, such as minutes per run, items processed or errors removed.
- Tie each number to the query, log or screenshot that produced it.
- For work with no number, state the goal, what you did, and the effects you saw, even indirect ones ([Evans 2019](https://jvns.ca/blog/brag-documents/)).
- Describe the work exactly as good as it was, no better and no worse.
- Revisit the piece months later and add what actually happened after launch.

### Honesty and credit

- Separate what you did from what the team did.
- Credit sources, tools and collaborators.
- Disclose meaningful AI assistance: what it produced and what you verified.
- State assumptions and limits, and what you would test next.
