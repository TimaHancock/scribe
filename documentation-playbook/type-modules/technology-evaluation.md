# Module: Technology evaluation

Status: Drafting · Last reviewed: 2026-10-19

Use this module for research that ends in a decision: adopt, trial, or pass. The document is an argument. It sets criteria first, collects evidence against them, and recommends one option while stating its drawbacks honestly.

## Covers and readers

**Covers:** product and vendor selection (backup, EDR, PSA), tool selection (a module, a monitoring stack), approach comparisons (configuration-as-code versus the portal, build versus buy), feasibility research ("can we offer this as a service?"), and proofs of concept.

**Doesn't cover:** analysis of how something works for its own sake, such as a protocol or vulnerability (Research deep-dive), or the rollout after the decision (IT project, which takes this module's decision record as its first input).

| Reader | What they need |
| --- | --- |
| Decision-maker | The recommendation, total cost, risk and deadline, on one page |
| Technical reviewer | Criteria, test method and evidence, enough to challenge a score |
| Implementer | Constraints and gotchas found during the proof of concept |
| Successor or future you | Why this option beat the others, and when to revisit |
| Portfolio reader | How you think: criteria, trade-offs and honest results |

## Template changes

Four documents, in order. The first is written before any vendor research.

1. **Evaluation brief:** the question phrased as a decision ("Should we replace X with Y for Z by \<date>?"), who decides, the deadline, constraints (budget, compliance, what it must integrate with), the long list of options including doing nothing, and a research timebox.
2. **Criteria matrix:** agree on the criteria and weights with the decision-maker before shortlisting, so they can't be bent to fit a favorite.
3. **Proof-of-concept plan and results:** test cases tied to criteria, the environment and versions, a pass threshold for each, and what actually happened.
4. **Recommendation and decision record:** a one-page summary up front, then a record in the [MADR](https://adr.github.io/madr/) shape: context, decision drivers, considered options, outcome, consequences, and confirmation (how you'll know it worked). Add the [Rust RFC template's](https://github.com/rust-lang/rfcs/blob/master/0000-template.md) Drawbacks section: the reasons against your own recommendation.

| Criterion | Weight | Must-have? | Option A | Option B | Do nothing | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Integrates with Entra ID SSO | — | Yes | Pass | Pass | n/a | PoC test 1 |
| Total cost over 3 years | 30% | No | 3 | 4 | 5 | Cost sheet |
| Admin effort per month | 25% | No | 4 | 2 | 2 | PoC timings |

Must-haves are pass or fail gates applied before scoring. Score the rest 1 to 5 against anchors written beforehand (for example, 5 means under 2 hours of admin a month). The weighted total supports the decision but doesn't make it: when the top two land close, the written trade-offs decide.

**Portfolio version:** "How I evaluated X" works well publicly. Vendor names and public facts are fine; quotes, discounts and roadmap briefings under NDA are not.

## Project directory

The core layout, with a folder per option, a proof-of-concept folder, and a private folder that never reaches `publish/`. It drops `scripts/` and `diagrams/` unless the proof of concept needs them.

```text
YYYY-MM-eval-slug/
  README.md          evaluation brief now, one-page recommendation later
  log.md             running log; tags SOURCE, CLAIM, VERIFIED
  criteria.xlsx      (new) weighted matrix and scoring anchors,
                     agreed before shortlisting
  cost.xlsx          (new) total cost over the term
  options/           (new) one folder per shortlisted option
    option-a/
      notes.md       capabilities, limits, demo and reference-call notes
      docs/          vendor docs, saved with version and date in the name
    option-b/
    do-nothing/
      notes.md       what staying put costs and risks
  poc/               (new) proof of concept
    plan.md          test cases, environment, pass thresholds
    results.md       outcome per test case, linked to evidence
  evidence/
    screenshots/     what the product actually did, dated
    terminal/
    exports/
  private/           (new) quotes, pricing, NDA briefings; never published
  decisions/
    NNN-slug.md      the MADR record; file a copy in the team's decision log
  drafts/
  publish/           "How I evaluated X", with nothing from private/
```

- **Name options neutrally** while scoring, such as `option-a`, if you want to limit brand bias when others review the matrix. Rename the folders after the decision.
- **Keep `private/` out of shared copies entirely.** If the folder is synced or in a shared repo, add it to `.gitignore` or store it elsewhere and link to it.
- **If the answer is adopt,** copy the decision record into the IT project's `decisions/`, and link `poc/results.md` from its brief. Proof-of-concept gotchas belong in the project's risks.

## Capture specifics and evidence standard

Research goes stale fast, because products change every quarter. Date everything, and keep what a vendor says separate from what you saw.

- **Source log:** URL, date accessed, and the product or document version for every fact you use. Tag SOURCE.
- **Claims versus verified:** tag a vendor statement CLAIM when you log it. Retag it VERIFIED only after your own test confirms it.
- **Test environment:** tenant or lab details, product versions, and settings changed from default.
- **Quotes and pricing:** date, quote number, what's included and when it expires. Keep these in private notes.
- **Demos and reference calls:** date, who presented, and the questions they dodged.

Evidence, strongest first:

| Strength | Source | How to use it |
| --- | --- | --- |
| 1 | Your own test in your environment | Can carry a score alone |
| 2 | Independent tests that publish their method | Strong, if the version matches yours |
| 3 | Vendor technical documentation | Good for capabilities and stated limits |
| 4 | Peers and community reports | A signal to test, not proof |
| 5 | Vendor marketing and sales claims | A claim to verify, never a score by itself |

Every score in the matrix links to its evidence. A score that rests only on a vendor claim is marked "claimed" in the cell.

## Safety and rules

Evaluations touch outside companies, so contracts and conflicts matter as much as data. These rules sit on top of the core redaction pass.

- **Keep trials out of production.** Run trials in a test tenant or lab. Connecting one to a production tenant or real client data needs approval first.
- **Review what trials can reach.** SaaS trials often ask for admin consent in Entra ID. Record the permissions granted, and revoke them and remove the app when the trial ends.
- **No company data in vendor tools.** Don't upload real data to test a tool, including AI tools, without approval. Use synthetic or redacted samples.
- **Read the license.** Evaluation licenses often forbid production use, and some vendor agreements forbid publishing benchmark results. Check before a comparison goes public.
- **NDA material stays private.** Pricing, discounts and roadmap briefings are often under NDA. Keep them out of shared and portfolio versions.
- **Disclose conflicts.** Partner margins, referral fees, resale agreements and personal relationships with vendors bias the result. Name them in the brief.
- **Security posture counts as a criterion.** Include the vendor's audit reports (such as SOC 2), data location and breach history in the criteria, not as an afterthought.

## Evaluation flow

The order protects the result: criteria come before options, and evidence comes before scores.

1. **Frame the question.** Write the brief, and get the decision-maker to agree on the question, deadline and timebox.
2. **Set criteria and weights.** Agree on them before looking closely at any option.
3. **Shortlist.** Use desk research to apply the must-haves to the long list, and keep doing nothing as an option.
4. **Research the shortlist.** Read documentation, sit through demos and make reference calls, logging claims as you go.
5. **Run the proof of concept.** Test the top one to three options against the test cases.
6. **Score and recommend.** Fill the matrix with linked evidence, then write the recommendation with its drawbacks.
7. **Decide and record it.** File the decision record in the decision log, with a confirmation check and a trigger for revisiting it.
8. **Hand off.** If the answer is adopt, it becomes an IT project, and the decision record goes in its brief.
9. **Revisit.** Reopen the decision at the trigger: contract renewal, a 12-month mark, a major incident or a big product change.

### Team technology radar

Across many evaluations, keep a team radar so past decisions are visible at a glance. Thoughtworks' [Build Your Own Radar](https://thoughtworks.com/insights/blog/build-your-own-technology-radar) uses four rings: **Adopt** (use it where it fits), **Trial** (pilot it on low-risk real work), **Assess** (worth exploring), and **Hold** (don't start new work with it). Each entry links to its decision record. Review the radar at least once a year.

## Tools

- **A spreadsheet:** the weighted criteria matrix and the 3-year cost sheet (licenses, labor, migration and exit costs).
- **Zotero or a source log:** dated sources with versions.
- **A test tenant or lab:** proofs of concept that never touch production.
- **Save-Screenshot.ps1:** dated evidence of what the product actually did.
- **The MADR template:** the decision record, filed in the same decision log your projects use.
- **[Build Your Own Radar](https://thoughtworks.com/insights/blog/build-your-own-technology-radar):** the team radar.

## Exemplars

- [MADR](https://adr.github.io/madr/): steal decision drivers, considered options and the confirmation field.
- [Rust RFC template](https://github.com/rust-lang/rfcs/blob/master/0000-template.md): steal Drawbacks, Rationale and alternatives, and Prior art.
- [Thoughtworks: Build Your Own Radar](https://thoughtworks.com/insights/blog/build-your-own-technology-radar): steal the four rings, and the point that the short write-up behind each entry is where the value lies.

## Checklist additions

- [ ] The question is phrased as a decision, with an owner and a deadline
- [ ] Criteria and weights were set before shortlisting
- [ ] Doing nothing was considered
- [ ] Every score links to evidence, and claims are marked as claims
- [ ] Sources are dated, with product versions
- [ ] Total cost covers the full term, including labor and exit
- [ ] The recommendation states its own drawbacks
- [ ] A confirmation check and a revisit trigger are set
- [ ] Trial access was revoked, and NDA material is out of shared versions
- [ ] Conflicts of interest are disclosed

## Rubric adjustments

- **Weight Reasoning highest:** alternatives and trade-offs compared fairly is the point of the document.
- **Tighten Evidence:** exemplary means every score traces to a dated source or your own test.
- **Narrow Reproducibility:** the proof-of-concept method should be repeatable; desk research only needs dated sources.
- **Redefine Results:** a clear decision with a confirmation check. Before and after metrics come later, in the IT project.
