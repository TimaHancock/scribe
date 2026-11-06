# Module: Coding project

Status: Drafting · Last reviewed: 2026-11-05

Use this module for anything you build in code: scripts, tools, modules, apps and games. A coding project produces two things that need different documentation. The repository is the product, and its docs serve the people who install, run and change it. The writeup is the story, and it serves the portfolio reader. This module keeps the two apart: what belongs to the code lives in the repo, and the private record of how you built it lives in the workspace around the repo.

This module replaces the planned Automation script or tool and Software or product build modules. The two are covered as tracks below. Its project directory has two sub-types, one for a Python repository and one for a PowerShell module repository.

## Covers and readers

**Covers:** PowerShell and Python scripts, CLIs and modules, scheduled jobs, web apps, SaaS tools, games and study tools.

| Track | Typical project | What changes |
| --- | --- | --- |
| Tool | A script or module you and your team run, such as an audit or reporting tool | Lighter: README, tests and changelog; versions only when others depend on it |
| Product | Something other people install, use or visit | Fuller: releases, CI, user docs, support and a deployment record |

**Doesn't cover:** the runbook for operating a tool in production (Runbook or SOP), choosing between frameworks or vendors when the choice is large (Technology evaluation; small choices go in the repo's decision records), or rolling a tool out across a work environment (IT project).

| Reader | What they need | Where they find it |
| --- | --- | --- |
| User | What it does, how to install, configure and run it, and its limits | README.md |
| Maintainer or future you | How it fits together, why it was built this way, how to test and release | docs/, decision records, CHANGELOG.md |
| Reviewer or hiring manager | The problem, your design decisions and signs of quality: tests, CI, a clean README | The writeup, plus the repo |
| Security reviewer | Dependencies, secrets handling, the permissions it needs | README, pyproject.toml or the module manifest, CI results |

## Template changes

Several writeup sections move into the repo, where they stay current with the code. The writeup links to them instead of repeating them.

1. **README.md** (in the repo): one sentence on what it does and for whom, then install, a quickstart that works when pasted, configuration, usage examples, limitations and license. A GIF or screenshot of it running goes near the top.
2. **Decision records** (in `docs/decisions/` in the repo, not in the workspace): one per structural choice, in the core template's shape. They're public, because a reviewer reading why you chose something learns more than from the code.
3. **docs/architecture.md:** the main parts, how data flows between them, and a Mermaid diagram, kept short enough to update.
4. **CHANGELOG.md:** one entry per release, grouped as Added, Changed, Fixed and Removed, in the [Keep a Changelog](https://keepachangelog.com/) format, with [semantic version](https://semver.org/) numbers.
5. **The writeup** keeps the story and adds two sections:
    - **Design:** the architecture diagram and the three or four decisions that shaped the project, each linking to its record.
    - **Quality:** how you know it works (tests, CI, benchmarks), stated as evidence rather than adjectives.

    Its Walkthrough becomes the hard problems and how you solved them, not a tour of the code. Its Environment section becomes supported versions and platforms.

**Work in issues.** Open an issue for each feature or bug, even working alone, and reference it in commits, as in Simon Willison's [How I build a feature](https://simonwillison.net/2022/Jan/12/how-i-build-a-feature/). The issue thread becomes your design notes, and its links tie the log, commits and changelog together.

## Project directory

The workspace wraps the repository. Nothing private goes in the repo, and the repo never contains the workspace.

```text
YYYY-MM-project-slug/
  README.md          kickoff card (private); the repo has its own README
  log.md             running log; link issue numbers and commit hashes
  evidence/
    screenshots/     UI states, before and after
    terminal/        transcripts of interesting failures and fixes
    exports/         benchmark and profiler output, with versions noted
  drafts/            writeup drafts
  publish/           the sanitized writeup only
  repo/              (new) the Git repository, one of the sub-types below
```

Changes from the core layout: `decisions/`, `scripts/` and `diagrams/` move into the repo (`docs/decisions/`, the code itself and `docs/`), because they describe the code and should travel with it.

`New-Project.ps1` builds the workspace and one of the sub-types below, with `-Module CodingPython` or `-Module CodingPowerShell`. It fills `repo/` with a small skeleton whose tests pass, and starts a Git repository there when Git is installed. Scribe and the `log DECISION ... -Record` command write decision records to `repo/docs/decisions/` once that folder exists.

### Sub-type: Python repository

A sound starting layout for an application or library, following the [Python Packaging User Guide's src layout](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/) and [pytest's good practices](https://docs.pytest.org/en/stable/explanation/goodpractices.html):

```text
repo/
  .gitignore                .venv/, __pycache__/, .env, dist/, coverage files
  .env.example              every variable the app reads, with placeholder values
  .pre-commit-config.yaml   lint, format and secret scan before every commit
  .github/workflows/ci.yml  tests and lint on every push
  LICENSE
  README.md
  CHANGELOG.md
  pyproject.toml            metadata, dependencies, entry points, tool settings
  uv.lock                   locked versions; commit it for applications
  docs/
    architecture.md
    decisions/
      001-use-src-layout.md
  src/
    project_name/
      __init__.py
      __main__.py           enables python -m project_name
      cli.py                argument parsing only; calls into the package
      core/
        __init__.py
        config.py           loads settings and environment variables
        errors.py           the package's exception types
      pipeline/             domain logic, named for what it does
        __init__.py
        processor.py
  tests/
    conftest.py
    test_cli.py
    pipeline/
      test_processor.py     mirrors src/project_name/pipeline/processor.py
```

- **Mirror the package in `tests/`,** and set `addopts = ["--import-mode=importlib"]` under `[tool.pytest.ini_options]`. pytest recommends this mode for new projects, and it lets test files in different folders share a name without `__init__.py` files in `tests/`.
- **Declare the command in `pyproject.toml`** with `[project.scripts]`, so installing the package puts it on the PATH, and keep `__main__.py` for `python -m`.
- **Name modules for their job.** A `utils/` folder tends to collect unrelated code; move each helper next to the code that uses it, or into a module named for what it does.
- **Dev tools go in a dependency group** (`[dependency-groups]` in `pyproject.toml`), not in the runtime dependencies.

### Sub-type: PowerShell module repository

```text
repo/
  .gitignore
  LICENSE
  README.md
  CHANGELOG.md
  PSScriptAnalyzerSettings.psd1
  .github/workflows/ci.yml       Pester and PSScriptAnalyzer on every push
  docs/
    decisions/
  src/
    ModuleName/
      ModuleName.psd1            manifest: version, required modules, exported functions
      ModuleName.psm1            dot-sources Public/ and Private/
      Public/
        Get-Thing.ps1            one exported function per file
      Private/
        ConvertTo-Helper.ps1
  tests/
    Public/
      Get-Thing.Tests.ps1        Pester tests, mirroring src/
```

For a single-script tool, the script, a README, a Pester test file and a CHANGELOG.md are enough. Comment-based help (`.SYNOPSIS`, `.PARAMETER`, `.EXAMPLE`) is its user documentation, so keep it complete.

## Capture specifics and evidence standard

Git records what changed. The log records why, what you tried and what it cost. Don't duplicate the commit history in the log.

- **Link, don't copy.** Log entries reference issue numbers and short commit hashes (`#14`, `a3f9c21`), so the writeup can point to the exact change.
- **DEAD entries name the branch or commit** of the abandoned attempt. Keep the branch until the writeup is done.
- **Decisions:** log a DECISION line, then write the record in `repo/docs/decisions/`.
- **Spikes:** time-boxed throwaway experiments. Log the question, the timebox and the answer. The answer is what survives, not the code.
- **Measurements:** save benchmark and profiler output under `evidence/exports/`, with the tool version, runtime version and machine noted. Numbers without conditions can't be compared.
- **Demos:** record terminal sessions with a tool like vhs or asciinema for the README, and screenshot UI states before and after each visible change.

| Claim | What proves it |
| --- | --- |
| "It works" | A passing CI run on the tagged release, linked |
| "Handles edge case X" | A test named for that case |
| "Faster" | A benchmark script in the repo, run before and after on the same machine, with output saved |
| "Easy to install" | A clean install in a fresh environment or container, following only the README |
| "Secure" | Scanner results and the specific risks you addressed, never the adjective alone |

## Safety and rules

Public repos are permanent: forks, caches and archives keep what you push, even after you delete it. These rules sit on top of the core redaction pass.

- **Secrets never enter the repo.** `.env` stays in `.gitignore`, and `.env.example` holds placeholders only. Run a secret scanner such as gitleaks in pre-commit and in CI. If a secret is pushed, rotate it at once; rewriting history doesn't make it safe again.
- **Check who owns work code.** Code written for your employer, or on its time or equipment, may belong to the employer. Get permission before publishing it, or rebuild the idea from scratch with fictional data.
- **Scrub history, not just the latest version.** Tenant IDs, internal hostnames, domains and user names in old commits, test fixtures or sample output leak as surely as in current files. Start a clean repo for publishing if the history can't be cleaned.
- **Publish under a private commit email.** Every commit carries its author's email address. Use the no-reply address your Git host provides (GitHub: Settings, Emails) before the first public push, or the address is published with the history.
- **Test data is synthetic.** Fixtures use fictional names and the `example.com` family of domains, never exports from a real environment.
- **Choose a license.** Without one, others have no right to use your code. Check that your dependencies' licenses allow your choice.
- **Treat dependencies as code you run.** Lock versions, look at a package's maintenance and download history before adding it, and watch for look-alike names. Run `pip-audit` or a similar check in CI.
- **Don't write your own cryptography.** Use a maintained library, such as `cryptography` for Python, and document the choice in a decision record.
- **Destructive operations default to safe.** Tools that change systems support a dry run (`-WhatIf` in PowerShell, `--dry-run` in Python CLIs) and ask for the least privilege they need. Document the exact permissions in the README.
- **Review and disclose AI-written code** as the core playbook requires, and make sure you can explain every line you publish.

## Development flow

| Phase | Documentation it produces | Done when |
| --- | --- | --- |
| 1. Frame | Kickoff card, first issues | The problem, users and done criteria are written |
| 2. Spike | Log entries with the question and answer | Each unknown that blocked the design is answered or explicitly deferred |
| 3. Design | `docs/architecture.md`, first decision records | You can draw the parts and explain the main choices |
| 4. Build | Commits linked to issues; tests and docs in the same change as the code | Every done criterion has a passing test or a recorded check |
| 5. Release | Version bump, CHANGELOG.md entry, Git tag, release notes | CI passes on the tag, and a fresh install works |
| 6. Write up | Writeup at the first meaningful milestone, not at the end | The quality bar passes |
| 7. Maintain | Dependency updates, changelog entries, an archive note if you stop | Reviewed at least yearly, or marked unmaintained in the README |

The Tool track can merge Release into Build: tag a version only when someone else depends on it. The Product track adds a deployment record, plus a runbook for anything you operate.

## Tools

- **uv:** Python versions, virtual environments, dependencies and the lock file.
- **Ruff:** Python linting and formatting in one fast tool.
- **mypy or Pyright:** type checking, if you use type hints.
- **pytest with pytest-cov:** tests and coverage. Treat coverage as a map of untested code, not a score.
- **Pester and PSScriptAnalyzer:** tests and linting for PowerShell.
- **pre-commit and gitleaks:** lint and secret scanning before every commit.
- **pip-audit:** known vulnerabilities in Python dependencies.
- **GitHub Actions or another CI:** runs the checks on every push, so "it works" has proof attached.
- **vhs or asciinema:** terminal demos for the README.
- **Scribe and the terminal commands:** screenshots and log entries in the workspace; `log ... | Save-Proof` keeps test and benchmark output as evidence.

## Exemplars

- [How I build a feature](https://simonwillison.net/2022/Jan/12/how-i-build-a-feature/): steal the issue for every change, with docs and tests in the same commit as the code.
- [Awesome README](https://github.com/matiassingers/awesome-readme): steal README structures that get someone from landing to running quickly.
- [Keep a Changelog](https://keepachangelog.com/): steal changelogs written for people, grouped by kind of change.
- [Python Packaging User Guide: src layout vs flat layout](https://packaging.python.org/en/latest/discussions/src-layout-vs-flat-layout/): steal the reasoning behind the layout, for your first decision record.
- [Oxide RFD 1](https://rfd.shared.oxide.computer/rfd/0001): steal writing a design down for discussion before building, for larger product work.

## Checklist additions

- [ ] The README states what it does, for whom, how to install and run it, and its limits
- [ ] A fresh clone, installed by following only the README, passes its tests
- [ ] CI passes on the tagged version the writeup describes
- [ ] Each claim in the writeup traces to a test, benchmark or CI run
- [ ] No secrets in the repo or its history, confirmed by a scan of the full history
- [ ] No employer or client identifiers in code, fixtures, sample output or history
- [ ] Commits carry a no-reply author email, not a personal or work address
- [ ] A license is present, and dependency licenses are compatible
- [ ] CHANGELOG.md and the Git tag match the version in the writeup
- [ ] Structural decisions have records in `docs/decisions/`
- [ ] The demo GIF or screenshots show the current version

## Rubric adjustments

- **Tighten Reproducibility:** exemplary means CI proves a clean install and test run, not that a peer could probably manage it.
- **Tighten Evidence:** tests, benchmarks and CI runs are the proof. A claim without one is weak, however good the code looks.
- **Add Maintainability:** someone else could install, change, test and release it from the repo's docs alone.
- **Extend Presentation to the repo:** the README is judged with the writeup, because most readers see it first.
- **Reasoning stays high:** decision records with alternatives count here.
