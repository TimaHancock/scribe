<#
.SYNOPSIS
    Creates a new project workspace in the documentation playbook's layout.
    Authors: Claude and Tima

.DESCRIPTION
    Asks for a project slug and a type module, then builds the folder tree for
    that module with a kickoff-card README.md and an empty log.md. The folder
    is named YYYY-MM-<slug> and goes in projectsFolder from settings.json, or
    wherever you pick when that isn't set.

    The kickoff card, the academic kickoff additions and the runbook procedure
    come from documentation-playbook\, so a template is edited in one place.
    The README gets frontmatter (type, status, module, started, updated) for
    Obsidian. When the parent folder is inside an Obsidian vault and has no
    .base file yet, Projects.base is copied there as a dashboard of projects.

    Module trees match the Project directory section of each type module:
      Core       the core layout, for anything without a module
      ITProject  change records, comms, before/after evidence, handover pack
      Runbook    authoring workspace for writing and testing one procedure
      TechEval   options, proof of concept, private folder, MADR decision
      Academic   one graded task: task snapshot, matrix, submitted, feedback
      Capstone   one root, shared evidence, one folder per task
      CodingPython      workspace around repo\, a Python src-layout repository
      CodingPowerShell  workspace around repo\, a PowerShell module repository

    The two coding types fill repo\ with a skeleton whose tests pass (the
    package or module is named after the project) and start a Git repository
    there when Git is installed.

    Afterward it can make the new folder the active project, so
    Start-Scribe.ps1 and Save-Screenshot.ps1 write into it.

.PARAMETER Slug
    Short project name, e.g. "proxy lab" or "net101 task 1". Turned into
    lowercase-hyphen form. Prompted for if omitted.

.PARAMETER Path
    Parent folder to create the project in. Defaults to projectsFolder in
    settings.json; a folder picker opens if that isn't set either.

.PARAMETER Module
    Which layout to build. Prompted for if omitted.

.PARAMETER Tasks
    Number of task folders for a Capstone project. Prompted for if omitted.

.PARAMETER SetActive
    Make the new folder the active project without asking.

.EXAMPLE
    powershell.exe -STA -File .\New-Project.ps1

.EXAMPLE
    .\New-Project.ps1 -Slug "senior capstone" -Module Capstone -Tasks 3 -Path D:\Projects -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Slug,
    [string]$Path,
    [ValidateSet('Core', 'ITProject', 'Runbook', 'TechEval', 'Academic', 'Capstone', 'CodingPython', 'CodingPowerShell')]
    [string]$Module,
    [ValidateRange(1, 12)]
    [int]$Tasks,
    [switch]$SetActive
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ProjectLog.psm1') -Force

$utf8 = New-Object Text.UTF8Encoding $false
$today = Get-Date

function Select-ParentFolder {
    $last = Get-ProjectLogStatePath 'last-parent.txt'
    $start = if (Test-Path -LiteralPath $last) { (Get-Content -LiteralPath $last -Raw).Trim() } else { $null }

    $canPick = $IsWindows -ne $false -and [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'
    if (-not $canPick) {
        return Read-Host 'Parent folder for the project (run with -STA on Windows for a folder picker)'
    }
    Add-Type -AssemblyName System.Windows.Forms
    # A hidden topmost owner keeps the picker from opening behind the console.
    $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false; Opacity = 0 }
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Where should the new project folder go?'
    $dialog.ShowNewFolderButton = $true
    if ($start -and (Test-Path -LiteralPath $start)) { $dialog.SelectedPath = $start }
    try {
        $owner.Show(); $owner.Activate()
        if ($dialog.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) { return $dialog.SelectedPath }
        return $null
    }
    finally { $dialog.Dispose(); $owner.Dispose() }
}

function Select-Module {
    $choices = [ordered]@{
        '1' = @('Core', 'no type module')
        '2' = @('ITProject', 'migration, deployment, rollout, decommission')
        '3' = @('Runbook', 'writing or overhauling one procedure')
        '4' = @('TechEval', 'choosing a product, tool or approach')
        '5' = @('Academic', 'one graded task')
        '6' = @('Capstone', 'multi-task capstone')
        '7' = @('CodingPython', 'coding project, Python repository')
        '8' = @('CodingPowerShell', 'coding project, PowerShell module repository')
    }
    Write-Host 'Type module:'
    foreach ($k in $choices.Keys) { Write-Host ("  {0}. {1,-16} {2}" -f $k, $choices[$k][0], $choices[$k][1]) }
    $pick = Read-Host 'Choose 1-8 (Enter for Core)'
    if (-not $pick) { return 'Core' }
    if (-not $choices.Contains($pick)) { throw "No module numbered '$pick'." }
    return $choices[$pick][0]
}

# --- File templates -----------------------------------------------------------

$moduleNames = @{
    Core = 'none'; ITProject = 'IT project'; Runbook = 'Runbook or SOP'
    TechEval = 'Technology evaluation'; Academic = 'Academic assessment'; Capstone = 'Academic assessment (capstone)'
    CodingPython = 'Coding project (Python)'; CodingPowerShell = 'Coding project (PowerShell)'
}
$playbook = Join-Path $PSScriptRoot 'documentation-playbook'

function Get-KickoffCard([string]$ModuleName) {
    $card = Get-PlaybookTemplate 'templates\01-kickoff-card.md'
    $date = $today.ToString('yyyy-MM-dd')
    $card = $card -replace '(?m)^(started|updated): YYYY-MM-DD', "`$1: $date"
    return $card -replace '(?m)^module: <[^>\r\n]*>', "module: $ModuleName"
}

$matrix = @"
# Rubric traceability matrix

| Rubric row | Verb and threshold | Heading in submission | Evidence and location | Status |
| --- | --- | --- | --- | --- |
| A1 | | | | Not started |
"@

$citations = @"
# Citations log

| Source | Author or organization | Date | URL | Accessed | Used for |
| --- | --- | --- | --- | --- | --- |
"@

# --- Layouts: folders, then files (relative path => content) ------------------

function Get-Layout([string]$Name, [int]$TaskCount, [string]$Folder) {
    $evidence = @('evidence/screenshots', 'evidence/terminal', 'evidence/exports')
    switch ($Name) {
        'Core' {
            @{ Folders = @('decisions') + $evidence + @('scripts', 'diagrams', 'drafts', 'publish')
               Files   = @{} }
        }
        'ITProject' {
            @{ Folders = @('decisions', 'changes', 'comms', 'evidence/before', 'evidence/after/wave-1') + $evidence +
                         @('scripts', 'diagrams', 'handover/runbooks', 'drafts', 'publish')
               Files   = @{ 'handover/as-built.md' = "# As-built`n`nHow the system works now: diagram, configuration summary, where things live, owners, monitoring and alerts, linked runbooks, known issues, vault references.`n" } }
        }
        'Runbook' {
            @{ Folders = @('evidence/runs', 'evidence/screenshots', 'evidence/terminal', 'scripts', 'publish')
               Files   = @{ 'procedure.md' = (Get-PlaybookTemplate 'type-modules\runbook-or-sop.md' -Heading '## Template changes') } }
        }
        'TechEval' {
            @{ Folders = @('options/option-a/docs', 'options/option-b/docs', 'options/do-nothing', 'poc') + $evidence +
                         @('private', 'decisions', 'drafts', 'publish')
               Files   = @{
                   'criteria.csv'               = "Criterion,Weight,Must-have,Option A,Option B,Do nothing,Evidence`n"
                   'cost.csv'                   = "Cost item,Option A,Option B,Do nothing,Notes`n"
                   'options/option-a/notes.md'  = "# Option A`n`nCapabilities, limits, demo and reference-call notes. Tag vendor statements CLAIM until verified.`n"
                   'options/option-b/notes.md'  = "# Option B`n`nCapabilities, limits, demo and reference-call notes. Tag vendor statements CLAIM until verified.`n"
                   'options/do-nothing/notes.md'= "# Do nothing`n`nWhat staying put costs and risks.`n"
                   'poc/plan.md'                = "# Proof-of-concept plan`n`n| Test case | Criterion | Environment | Pass threshold |`n| --- | --- | --- | --- |`n"
                   'poc/results.md'             = "# Proof-of-concept results`n`n| Test case | Result | Evidence |`n| --- | --- | --- |`n"
                   'private/README.md'          = "Quotes, pricing and NDA material. Never copy anything from here to publish/.`n"
               } }
        }
        'Academic' {
            @{ Folders = @('task', 'sources', 'decisions') + $evidence + @('scripts', 'diagrams', 'drafts', 'submitted', 'feedback', 'publish')
               Files   = @{ 'matrix.md' = $matrix; 'sources/citations.md' = $citations } }
        }
        'Capstone' {
            $folders = @('sources', 'decisions') + $evidence + @('publish')
            $files = @{ 'sources/citations.md' = $citations }
            foreach ($n in 1..$TaskCount) {
                $t = "task-$n"
                $folders += @("$t/task", "$t/drafts", "$t/submitted", "$t/feedback")
                $files["$t/matrix.md"] = $matrix
            }
            @{ Folders = $folders; Files = $files }
        }
        'CodingPython'     { Get-CodingLayout -Kind Python -Folder $Folder -Evidence $evidence }
        'CodingPowerShell' { Get-CodingLayout -Kind PowerShell -Folder $Folder -Evidence $evidence }
    }
}

# --- Coding projects: the workspace wraps repo\ --------------------------------
#
# Trees follow the Project directory sub-types in
# documentation-playbook\type-modules\coding-project.md. File contents use
# tokens: __DIST__ (proxy-lab), __PKG__ (proxy_lab), __ENV__ (PROXY_LAB),
# __MOD__ (ProxyLab), __TITLE__ (proxy lab) and __GUID__.

$codingCommon = @{
    'LICENSE' = @'
No license chosen yet.

Pick one before publishing (https://choosealicense.com/), then replace this
file with its text. Without a license, nobody else has the right to use,
change or share this code. Check that your dependencies' licenses allow your
choice.
'@
    'CHANGELOG.md' = @'
# Changelog

All notable changes are recorded here, in the [Keep a Changelog](https://keepachangelog.com/)
format. Versions follow [semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- Project skeleton.
'@
}

$pythonFiles = @{
    '.gitignore' = @'
.venv/
__pycache__/
*.py[cod]
.env
dist/
build/
*.egg-info/
.coverage
coverage.xml
htmlcov/
.pytest_cache/
.ruff_cache/
.mypy_cache/
'@
    '.env.example' = @'
# Every variable the app reads, with placeholder values only.
# Copy to .env for real values; .env is never committed.
# __ENV___API_URL=https://api.example.com
'@
    '.pre-commit-config.yaml' = @'
# Lint, format and secret scan before every commit.
# Install with: pre-commit install. Refresh the pinned versions with: pre-commit autoupdate
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
      - id: ruff-format
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks:
      - id: gitleaks
'@
    '.github/workflows/ci.yml' = @'
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install
        run: python -m pip install -e . pytest ruff
      - name: Lint
        run: ruff check .
      - name: Test
        run: pytest
'@
    'README.md' = @'
# __TITLE__

One sentence: what it does and for whom.

## Install

```
python -m pip install .
```

## Quickstart

```
__DIST__ --help
python -m __PKG__ --help
```

## Configuration

Settings come from environment variables; `.env.example` lists each one.

## Limitations

What it doesn't do, and the platforms and versions it supports.

## Development

```
uv sync          # or: python -m pip install -e . pytest ruff
pytest
ruff check .
```

## License

See [LICENSE](LICENSE).
'@
    'pyproject.toml' = @'
[project]
name = "__DIST__"
version = "0.1.0"
description = "One sentence: what it does and for whom."
readme = "README.md"
requires-python = ">=3.10"
dependencies = []

[project.scripts]
__DIST__ = "__PKG__.cli:main"

[dependency-groups]
dev = ["pytest", "pytest-cov", "ruff"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
addopts = ["--import-mode=importlib"]
pythonpath = ["src"]
testpaths = ["tests"]
'@
    'docs/architecture.md' = @'
# Architecture

The main parts, how data flows between them, and why. Keep it short enough to update.

```mermaid
flowchart LR
    cli["cli.py: arguments"] --> core["core/: config and errors"]
```
'@
    'src/__PKG__/__init__.py' = @'
"""__TITLE__: one sentence on what it does."""

__version__ = "0.1.0"
'@
    'src/__PKG__/__main__.py' = @'
"""Lets the package run as: python -m __PKG__"""

from .cli import main

raise SystemExit(main())
'@
    'src/__PKG__/cli.py' = @'
"""Command-line entry point: argument parsing only; the work happens in the package."""

import argparse

from . import __version__


def main(argv=None):
    parser = argparse.ArgumentParser(prog="__DIST__", description="One sentence: what it does.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.parse_args(argv)
    return 0
'@
    'src/__PKG__/core/__init__.py' = ''
    'src/__PKG__/core/config.py' = @'
"""Settings and environment variables, read in one place."""

import os


def get_setting(name, default=None):
    """One setting from the environment; .env.example lists the names."""
    return os.environ.get(name, default)
'@
    'src/__PKG__/core/errors.py' = @'
"""The package's exception types."""


class __MOD__Error(Exception):
    """Base class for errors this package raises on purpose."""
'@
    'tests/conftest.py' = @'
"""Shared pytest fixtures."""
'@
    'tests/test_cli.py' = @'
import pytest

from __PKG__ import __version__
from __PKG__.cli import main


def test_main_succeeds_with_no_arguments():
    assert main([]) == 0


def test_version_flag_prints_the_version(capsys):
    with pytest.raises(SystemExit):
        main(["--version"])
    assert __version__ in capsys.readouterr().out
'@
}

$powershellFiles = @{
    '.gitignore' = @'
out/
testResults.xml
coverage.xml
'@
    'PSScriptAnalyzerSettings.psd1' = @'
@{
    Severity = @('Error', 'Warning')
}
'@
    '.github/workflows/ci.yml' = @'
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        shell: pwsh
        run: |
          Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
          $issues = Invoke-ScriptAnalyzer -Path src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
          $issues
          if ($issues) { exit 1 }
      - name: Test
        shell: pwsh
        run: |
          Install-Module Pester -MinimumVersion 5.5 -Force -SkipPublisherCheck -Scope CurrentUser
          Invoke-Pester -Path tests -CI
'@
    'README.md' = @'
# __TITLE__

One sentence: what it does and for whom.

## Install

```powershell
Import-Module ./src/__MOD__/__MOD__.psd1
```

## Quickstart

```powershell
Get-Command -Module __MOD__
```

## Permissions

What it needs to run, and why. Commands that change systems support -WhatIf.

## Limitations

What it doesn't do, and the PowerShell versions and platforms it supports.

## Development

```powershell
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

## License

See [LICENSE](LICENSE).
'@
    'src/__MOD__/__MOD__.psd1' = @'
@{
    RootModule        = '__MOD__.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '__GUID__'
    Description       = 'One sentence: what it does and for whom.'
    PowerShellVersion = '5.1'
    # List each function in Public\ here as you add it.
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
'@
    'src/__MOD__/__MOD__.psm1' = @'
# Dot-sources one function per file. Public\ functions are exported; Private\ ones stay inside the module.
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue)
$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $public + $private) { . $file.FullName }
Export-ModuleMember -Function @($public | ForEach-Object { $_.BaseName })
'@
    'tests/Module.Tests.ps1' = @'
BeforeAll {
    $script:manifest = Join-Path $PSScriptRoot '..\src\__MOD__\__MOD__.psd1'
}

Describe '__MOD__ module' {
    It 'has a valid manifest' {
        { Test-ModuleManifest -Path $manifest -ErrorAction Stop } | Should -Not -Throw
    }
    It 'imports without errors' {
        { Import-Module $manifest -Force -ErrorAction Stop } | Should -Not -Throw
    }
}
'@
}

function Initialize-CodeRepository {
    <# git init in repo\, on a branch named main, when Git is installed. Nothing is committed. #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host 'Git is not installed, so repo\ is not a Git repository yet. Run git init there once it is.'
        return
    }
    # Git writes notices to stderr; that's not a failure here.
    $ErrorActionPreference = 'Continue'
    & git -C $Path init -q -b main 2>&1 | Out-Null
    if ($LASTEXITCODE) { & git -C $Path init -q 2>&1 | Out-Null }   # Git before 2.28 has no -b
    if ($LASTEXITCODE) { Write-Warning "git init failed in $Path; run it there yourself." }
    else { Write-Host "Started a Git repository in $Path (nothing committed yet)." }
}

function Get-CodingLayout {
    <# The coding workspace plus repo\ for one sub-type, with names taken from the project folder. #>
    param([ValidateSet('Python', 'PowerShell')][string]$Kind, [string]$Folder, [string[]]$Evidence)
    $base = $Folder -replace '^\d{4}-\d{2}-', ''
    $pkg = $base -replace '-', '_'
    if ($pkg -match '^\d') { $pkg = "app_$pkg" }   # a Python name can't start with a digit
    $mod = -join ($base -split '-' | ForEach-Object { if ($_) { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) } })
    if ($mod -match '^\d') { $mod = "App$mod" }   # also a Python class name in errors.py
    $tokens = [ordered]@{
        '__DIST__'  = $base
        '__PKG__'   = $pkg
        '__ENV__'   = $pkg.ToUpperInvariant()
        '__MOD__'   = $mod
        '__TITLE__' = $base -replace '-', ' '
        '__GUID__'  = [guid]::NewGuid().ToString()
    }
    $source = if ($Kind -eq 'Python') { $pythonFiles } else { $powershellFiles }
    $files = @{}
    foreach ($set in $codingCommon, $source) {
        foreach ($rel in $set.Keys) {
            $path = $rel
            $text = $set[$rel]
            foreach ($t in $tokens.Keys) { $path = $path.Replace($t, $tokens[$t]); $text = $text.Replace($t, $tokens[$t]) }
            $files["repo/$path"] = $text
        }
    }
    $folders = $Evidence + @('drafts', 'publish', 'repo/docs/decisions')
    if ($Kind -eq 'PowerShell') {
        $folders += @("repo/src/$($tokens['__MOD__'])/Public", "repo/src/$($tokens['__MOD__'])/Private", 'repo/tests/Public')
    }
    @{ Folders = $folders; Files = $files; Kind = $Kind }
}

# --- Gather input -------------------------------------------------------------

if (-not $Slug) { $Slug = Read-Host 'Project slug (e.g. "proxy lab" or "net101 task 1")' }
$clean = Get-ProjectFolderName -Name $Slug -When $today
if (-not $clean) { throw 'The slug needs at least one letter or number.' }

if (-not $Module) { $Module = Select-Module }
if ($Module -eq 'Capstone' -and -not $Tasks) {
    $answer = Read-Host 'How many capstone tasks? (Enter for 3)'
    $Tasks = if ($answer) { [int]$answer } else { 3 }
}

if (-not $Path) {
    $projectsFolder = (Get-ProjectLogSettings).projectsFolder
    if ($projectsFolder -and (Test-Path -LiteralPath $projectsFolder -PathType Container)) { $Path = $projectsFolder }
    else { $Path = Select-ParentFolder }
}
if (-not $Path) { Write-Host 'Cancelled.'; return }
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Parent folder not found: $Path" }

$root = Join-Path (Resolve-Path -LiteralPath $Path).ProviderPath $clean
if (Test-Path -LiteralPath $root) { throw "Already exists, nothing changed: $root" }

# --- Build --------------------------------------------------------------------

$layout = Get-Layout -Name $Module -TaskCount $Tasks -Folder $clean
$readme = Get-KickoffCard $moduleNames[$Module]
if ($Module -in 'Academic', 'Capstone') {
    $readme += "`n" + (Get-PlaybookTemplate 'type-modules\academic-assessment.md' -Heading '### Kickoff card additions')
}

# A projects dashboard for the vault, unless this folder already has a .base file.
$parent = Split-Path -Parent $root
$dashboard = $null
if ((Get-ObsidianVault -Path $parent) -and -not (Get-ChildItem -LiteralPath $parent -Filter '*.base' -File)) {
    $dashboard = Join-Path $parent 'Projects.base'
}

$files = @{
    'README.md' = $readme
    'log.md'    = "# Running log: $clean`n`n"
}
foreach ($k in $layout.Files.Keys) { $files[$k] = $layout.Files[$k] }

if ($PSCmdlet.ShouldProcess($root, "Create $Module project")) {
    New-Item -ItemType Directory -Path $root | Out-Null
    foreach ($folder in $layout.Folders) {
        New-Item -ItemType Directory -Path (Join-Path $root $folder) -Force | Out-Null
    }
    foreach ($rel in $files.Keys) {
        $target = Join-Path $root $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        $content = $files[$rel]
        if (-not $content.EndsWith("`n")) { $content += "`n" }
        [IO.File]::WriteAllText($target, ($content -replace "`r?`n", [Environment]::NewLine), $utf8)
    }

    $lastParent = Get-ProjectLogStatePath 'last-parent.txt'
    New-Item -ItemType Directory -Path (Split-Path -Parent $lastParent) -Force | Out-Null
    [IO.File]::WriteAllText($lastParent, (Split-Path -Parent $root), $utf8)

    Write-Host "Created $Module project: $root" -ForegroundColor Green
    if ($layout.Kind) {
        if ($layout.Kind -eq 'Python') {
            $record = New-DecisionRecord -Root $root -Decision 'Use the src layout; tests then run against the installed package, not the working folder'
            Write-Host "First decision record: $record"
        }
        Initialize-CodeRepository -Path (Join-Path $root 'repo')
    }
    if ($dashboard) {
        Copy-Item -LiteralPath (Join-Path $playbook 'templates\projects.base') -Destination $dashboard
        Write-Host "Added a projects dashboard for Obsidian: $dashboard"
    }

    $makeActive = $SetActive
    if (-not $makeActive) {
        $answer = Read-Host 'Make it the active project for the log box and screenshots? [Y/n]'
        $makeActive = -not $answer -or $answer -match '^(y|yes)$'
    }
    if ($makeActive) { [void](Set-ActiveProject -Path $root); Write-Host 'Active project set.' }
}
else {
    # -WhatIf: show what would be built.
    Write-Host "Would create: $root"
    ($layout.Folders + $files.Keys) | Sort-Object | ForEach-Object { Write-Host "  $_" }
    if ($dashboard) { Write-Host "Would add the projects dashboard: $dashboard" }
    if ($layout.Kind -eq 'Python') { Write-Host 'Would write the first decision record: repo/docs/decisions/001-use-the-src-layout.md' }
    if ($layout.Kind) { Write-Host 'Would start a Git repository in repo/ (when Git is installed)' }
}
