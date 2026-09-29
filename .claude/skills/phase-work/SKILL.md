---
name: phase-work
description: Start, continue, or plan work on a Nook roadmap phase (P0–P11) or a task inside one. Use when the user says "start P3", "work on the next phase", "pick up <task>", "what's left in this phase", or asks to implement any feature from the roadmap. Keeps work in scope, split into small PRs, and tied to acceptance criteria.
---

# Phase work

Nook is built in phases (`docs/02_Roadmap.md`), and each one is closed by acceptance, QA and regression checks. This skill keeps an agent inside the current phase's scope and working the way the team does.

## 1. Orient (always do this first)
1. Read `CLAUDE.md` if it isn't already in context.
2. Open `docs/02_Roadmap.md` and find the phase. Read its **Status**, **Scope**, **Lanes**, **Acceptance**, **QA** and **Regression**, plus the milestone's **Gate**.
3. Check that the previous milestone's gate has passed. If the phase belongs to a milestone whose gate hasn't passed (for example, starting P7 before G2), **stop and tell the user.**
4. Check the current state:
   - `git log --oneline -20` and `git branch -a`
   - open PRs, with `gh pr list` if available
   - which parts of the scope already exist in code
5. Pull in the referenced docs for the scope items only: screen sections in `01`, components in `03`, contracts in `04`, and `F#`/`US#` in `00_PRD.md`, plus any `D#` in `decisions.md` that touches them.

## 2. Restate the phase in 5 lines or fewer
Tell the user:
- What will be built
- What is explicitly **not** in this phase (later phases)
- The acceptance criteria you'll prove
- The lane(s) you're taking
- Any open `[Verify in SDK]` items you'll need

## 3. Split into tasks
- Each task is ≤ 2 days of work and ≤ ~400 lines of diff, owned by one lane (UI, Platform, AI, Design or QA), and touches only that lane's files. That's what lets teammates work in parallel.
- Order tasks so that `main` is always shippable. Put models and services before screens, and hide half-built screens behind a flag in `FeatureFlags` when needed.
- When the user asks, create GitHub issues on the milestone `P<N> – <name>` (confirm before creating anything on GitHub).

## 4. Implement a task
1. Branch: `git checkout -b p<N>/<short-task>` from an up-to-date `main`.
2. Use the specialized skill for the work:
   - `build-screen` for UI
   - `ai-capability` for anything routed through the router
   - `data-model-change` for SwiftData changes
3. Write tests alongside the code (see `docs/05_Testing_and_QA.md` §1). Every acceptance criterion needs a test or a documented manual check.
4. If you use an API tagged `[Verify in SDK]` (or any iOS 27 API you're unsure of), confirm it in the SDK or docs first, and add the finding to `docs/decisions.md`.
5. If behavior differs from the docs, update the docs in the same PR. If you made a new choice, add a `D#` entry.
6. Open a PR using `.github/pull_request_template.md` and fill in every checklist line honestly.

## 5. Out-of-scope discoveries
If you notice something that belongs to a later phase or another lane, **don't build it.** Note it in the PR description under "Follow-ups", or propose an issue.

## 6. Close the phase
Once all tasks are merged:
1. Run the `qa-regression` skill. It produces the phase QA report and the smoke-suite table.
2. Update the phase's **Status** line in `docs/02_Roadmap.md` to `Done (<date>, PR #…)`.
3. If this was the milestone's last phase, prepare the gate checklist for the team review. Gates are decided by people, not agents.

## Status values
`Not started` · `In progress (<owner>)` · `In QA` · `Done (<date>)` · `Blocked (<reason>)`
