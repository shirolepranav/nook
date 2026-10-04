---
name: qa-regression
description: Run QA for a Nook PR or close out a phase — phase QA cases, the cumulative smoke suite (S1–S14), accessibility checks, the "No AI" pass, performance budgets — and produce the QA report for the PR. Use when the user says "QA this", "close the phase", "run regression", "smoke test", or before a gate review.
---

# QA & regression

A phase isn't Done until its **Acceptance**, **QA** and **Regression** sections pass, **and** the cumulative smoke suite has been run and logged. Sources:
- `docs/02_Development_Roadmap.md`: the phase sections and the smoke-suite table
- `docs/05_Testing_and_QA.md`: methods, device matrix, a11y checklist, No-AI pass, severity, report template

## 1. Scope the run
- **A PR:** the acceptance items it claims, plus the smoke rows for the areas it touched, plus the unit, UI and snapshot suites.
- **Phase close:** everything in the phase, plus **every smoke row up to and including the phase** (see the "From" column).
- **Gate:** the phase close plus the gate's criteria. G2, G3 and G4 need the full device matrix and a No-AI pass.

## 2. Automated
Run the commands listed in `CLAUDE.md` → Commands:
- Unit tests for each package, and the app tests (unit, snapshot, UI) on the iPhone SE simulator.
- For a phase close: the UI tests on 18 Pro Max and a Duo configuration too.
- The perf tests if the phase touched a budgeted flow (04 §12).
- The policy greps (05 §2), if CI hasn't already run them.

Record the failures. **Don't** mark anything passed that you didn't actually run.

## 3. Manual / agent-driven checks
- If a simulator tool is available, drive the flows yourself: launch, tap through each smoke row, and take screenshots in light, dark and AX3.
- Verify with screenshots, not assumptions.
- Things an agent can't check are listed as **"Needs human"** with exact steps: real-device AI quality, haptics feel, Face ID, the system Camera scanning a QR code, two-device iCloud.
- For screens that were touched, run the accessibility checklist (05 §5).
- If the router or any capture, find or report flow was touched, do the **No-AI pass** (05 §6), including with **Force classic engine** on.

## 4. Triage
- Classify each failure P0–P3 (05 §8).
- P0 or P1 → the phase **can't close**. Open an issue for each (with confirmation before creating on GitHub) and list it in the report.
- Regressions in an earlier phase's smoke row are at least P1.

## 5. Report
Paste the template from `docs/05_Testing_and_QA.md` §9 into the PR, filled in:
- Builds and devices used.
- Every acceptance criterion with its evidence (a test name, a screenshot, or a measured number).
- The smoke table, one row per S#: `device · ✅/❌/⏭ · note`. ⏭ = not run, with the reason.
- Accessibility findings, No-AI result, performance numbers vs budgets.
- Open bugs with severity.

## 6. Close out (phase close only, when the report is green)
- Update the phase **Status** in `docs/02_Development_Roadmap.md` to `Done (<date>)`.
- If it's the last phase of a milestone, list the gate criteria and their evidence for the team's go/no-go. **People decide gates, not agents.**
