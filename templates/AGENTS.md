# Agent Instructions

> Single source of truth. CLAUDE.md is a 3-line stub pointing here.
> Every line below must be grep/test/hook-verifiable. No values, no "should".

## Commands
- build: <TODO>
- test:  <TODO>
- lint:  <TODO>

## Forbidden zones (enforced by .githooks)
- never commit .env / secrets/
- never push directly to main/master (use a PR from a feature branch)

## Commit boundary
- tests must pass before commit
- light task (one-key revertable + stays inside one module) → commit, then ask before push
- full task (cross-module / schema / CI / deps) → list a plan, get confirmation, commit, do NOT push

## Mode
loose   <!-- loose | strict. loose: commit then auto-push (never main). strict: plan→confirm→commit, no push. -->

## Read before you start a task
- docs/PROJECT.md   (project map; if stale, `git log --oneline -20` shows recent work)
- WORK.md           (only if it exists — parallel agents; append a claim line before you start)
- the Mode line above

## When to write memory (enforced by commit-msg hook)
- fixed a non-trivial bug → docs/memory/cases/<date>-<slug>.md  (frontmatter: tags/resolved/files/related)
- non-obvious architecture choice → docs/memory/decisions/<date>-<slug>.md
- touched code but nothing worth recording → add `Memory: none` (or `trivial`) trailer to the commit message
- before finishing: ask yourself "is there a case worth writing?"

## Anti-pattern log (prune quarterly so this file stays short)
<!-- e.g. 2026-05 some agent kept bypassing X; after fix this line can be deleted -->
