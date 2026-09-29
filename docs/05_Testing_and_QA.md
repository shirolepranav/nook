# Nook — Testing & QA

How we prove each phase works and keep earlier phases working. The per-phase QA and regression lists and the **cumulative smoke suite (S1–S14)** are in [02_Roadmap.md](02_Roadmap.md). This doc defines the methods those lists rely on. Use the `qa-regression` skill to run a phase's checks and produce the report.

---

## 1. Test layers

| Layer | Tool | Where | What | Runs |
|---|---|---|---|---|
| Unit | Swift Testing (`@Test`, `#expect`) | Each package's `Tests/` | Models, invariants, services, search ranking, scheduler, router fallback, report/CSV/backup | Every PR (CI) |
| Snapshot | Image snapshots of NookUI components and key screens | `NookUI` tests + `NookTests` | {light, dark} × {Large, AX3}, plus Increase Contrast for components | Every PR |
| UI flow | XCUITest | `NookUITests` | The 6 user stories plus the smoke suite rows that can be automated | Every PR (SE sim); nightly on the full matrix |
| App Intents | App Intents testing | `NookTests/Intents` | Find, Move, ListRoom, Add, ScanRoom | Every PR from P8 |
| AI quality | Evaluations framework [Verify in SDK] | `NookAI/Evaluations` + `Fixtures/eval` | Room-scan naming accuracy; question→query correctness | Per AI PR, on every iOS beta, before each release |
| Performance | XCTest metrics + Instruments | `NookTests/Perf` | PRD budgets (04 §12) | Nightly; release blocking in P11 |
| Manual | Checklists in this doc | Real devices | Device matrix, accessibility, No-AI pass, exploratory | End of phase; every release |

**Rules:**
- **Test the classic path first.** Every router method gets tests for the forced `.classic` engine, `.ai`, and AI throwing or timing out.
- **Inject time and the system.** Clocks, calendars, the notification center, availability and the file system are all injected. No test sleeps, and no test depends on the wall clock.
- **Fixtures are in the repo:** `Fixtures/receipts/` (50 receipts including crumpled, faded and foreign ones), `Fixtures/shelf/` (the G3 test shelf), `Fixtures/eval/` (100 labeled household photos), `Fixtures/seed/` (100, 1k and 5k items), and `Fixtures/golden/` (PDF page counts, CSV text).
- **A bug fix ships with a test** that fails without the fix.

---

## 2. CI (GitHub Actions, macOS runner, set up in P0)

- **On every PR to `main`:**
  - build with zero warnings
  - unit and snapshot tests
  - UI smoke on the iPhone SE simulator
  - the policy greps below
- **Policy greps** (fail the build when they match):

| Grep | Rule |
|---|---|
| `UIScreen.main`, `userInterfaceIdiom` | Size classes only |
| `import FoundationModels`/`import Vision` outside `Packages/NookAI` | The router contract |
| `URLSession` outside the allowlist | No network |
| `Color(red:`, `.font(.system(size:` in the app target | Tokens only |
| `@Attribute(.unique)` | CloudKit-safe |

- **Nightly:** UI tests on the full simulator matrix, the perf suite, and the evaluation set on an AI-capable runner (if available; otherwise run it manually on the team device).

---

## 3. Device matrix (PRD §4)

| Config | Type | Why |
|---|---|---|
| iPhone SE (3rd gen) | Simulator + real device if available | Smallest screen, Touch ID, no Apple Intelligence |
| iPhone 18 Pro | Simulator | Mainline |
| iPhone 18 Pro Max | Simulator | Largest slab; regular width in landscape |
| iPhone Duo: open, closed, rotated, half-folded, Split View both sides | Xcode 27.1 Device Hub | Size-class transitions, hinge, per-edge safe areas |
| **Real Apple Intelligence iPhone** (15 Pro or newer) | Device | AI path, performance budgets |
| **Real older iPhone** (no Apple Intelligence) | Device | Classic path, performance on slow hardware |

Each phase's QA runs on at least SE, 18 Pro Max and one Duo configuration. G2, G3 and G4 run the full matrix.

---

## 4. AI quality protocol

- **Test shelf (G3):**
  - 8 clear household items on a shelf, photographed in daylight from 1.5 m, straight on, with 3 captures.
  - A suggestion is **correct** if its name would let a person identify the item (the synonym list counts).
  - Pass: at least 6 of 8, averaged across the 3 runs, on the reference AI iPhone.
- **100-photo evaluation:**
  - Metrics: per-photo recall (items correctly named ÷ labeled items) and precision (correct ÷ suggested).
  - The baseline is recorded at G3. A drop of more than 5 points on an iOS update is a P1 bug.
- **Where-is evaluation (P8):**
  - 30 questions: 20 answerable, 5 about items that aren't recorded, and 5 move statements.
  - Pass criteria:
    - **Zero invented locations.** A record is required for every answer.
    - Every move statement produces a confirm card, never a write.
- **Where results go:** log them in the PR as `run date · iOS build · device · recall · precision · notes`.

---

## 5. Accessibility checklist (every screen, every phase that touches it)

- [ ] VoiceOver: every element has a label; cards read name, room and value; custom actions mirror swipes and menus; headings are marked; focus order is logical; toasts are announced.
- [ ] Dynamic Type: xSmall → AX5 without clipping; grids become lists at AX sizes; nothing essential is truncated.
- [ ] Contrast ≥ 4.5:1 for text and 3:1 for UI, checked in Accessibility Inspector in light, dark and Increase Contrast.
- [ ] Liquid Glass slider at both extremes; Reduce Transparency on: bars and the Capture button stay legible.
- [ ] Reduce Motion: no zoom, slide, bounce or shake, and cross-fades are used instead.
- [ ] Voice Control: "Tap Move", "Tap Save" and similar work using the visible names.
- [ ] Targets ≥ 44×44 pt with ≥ 8 pt spacing.
- [ ] The screen can be used **without the camera** and **without AI**.
- [ ] Bold Text, Button Shapes and Smart Invert (photos are not inverted).

In P11 the audit runs on every screen, and the App Store Accessibility Nutrition Label is filled in from the results.

---

## 6. "No AI" pass (G2, and every release)

1. Turn off Apple Intelligence on an AI device, and also run on a real non-AI iPhone.
2. Run US1–US6 and smoke rows S3–S10.
3. Pass criteria:
   - Every flow completes.
   - **No text anywhere mentions AI**, and no error appears.
   - The manual screens appear exactly where the AI screens would.
4. Also run with the debug toggle **Force classic engine** on an AI device, to catch any code that bypasses the router.

---

## 7. Performance

See the budget table in [04 §12](04_Architecture.md). Perf tests run on the 5k seed fixture. A regression over the budget blocks the phase. A change within 10% of the budget is flagged in the PR.

---

## 8. Bug severity (used by the whole team)

| Severity | Definition | Rule |
|---|---|---|
| **P0** | Crash, data loss, a privacy leak (Private item exposed, data leaving the device), or an unusable core flow (US1–US6) | Fix immediately. Blocks any gate |
| **P1** | A core flow is degraded, an accessibility blocker, a budget is missed, or the AI invents a location | Fix before the phase closes. Blocks gates |
| **P2** | A non-core bug with a workaround, or a visual defect that goes against 03 | Schedule within the milestone |
| **P3** | Polish | Backlog |

Bug reports need: steps, expected vs. actual result, device and configuration (including AI on or off and the Duo pose), a screenshot or video, and the PRD or decision ID if relevant.

---

## 9. Phase QA report (template, pasted into the phase's closing PR)

```
## P<N> QA report — <date>
Builds: <commit> · Devices: <list>
### Acceptance
- [x] <criterion> — evidence
### Phase QA
- [x] <case> — device — result
### Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | SE sim | ✅ | 312 ms |
### Accessibility (screens touched)
### No-AI check (if router touched)
### Open bugs
| ID | Sev | Summary |
```
