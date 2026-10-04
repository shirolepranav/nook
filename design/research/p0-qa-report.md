## P0 QA report: 2026-10-04
Builds: none (design phase) · Canvas: [Nook — App screens](https://claude.ai/artifact/MYsu1xGJDwiuHKrzksKHMU) · Repo: `main` @ b4838af + `p0/close`

### Acceptance (roadmap P0)
- [x] **Every screen has all states designed.** All 51 screens in `01` §2 are drawn, each with light, dark and AX5 versions plus every state `01` lists. Coverage table: `design/README.md`.
- [x] **Every flow has a Classic path.** Room scan (C-03/C-04), receipt (C-06), serial (C-08), item editor (I-02), Find (F-02 vs F-03/F-04), and the Apple Intelligence settings status (S-11).
- [x] **Text contrast passes 4.5:1.** `check_tokens.py` checks every token pair in light, dark and High Contrast (D24): 0 failures.

### Phase QA
- [~] **5 hallway tests:** replaced by an expert review (D27). See `design/research/p0-review.md`.
- [x] **Prototype integrity:** 0 dead links; all 50 screen components reachable from the start board.
- [x] **Cognitive walkthrough of US1–US6:** all within target. US1 by hand is borderline (finding 5).

### Regression: design consistency review
- [x] Tokens only: 0 untokenized colors, 0 off-grid spacing values, 0 off-scale font sizes across 281 boards.
- [x] Glass only on controls (tab bar, toolbars, Capture, camera controls); content stays on paper surfaces.

### Smoke suite
None in P0 (S1 starts in P1).

### Accessibility (screens touched: all)
Built as designed (labels, 44-pt targets, AX5 boards, contrast). VoiceOver and Voice Control behavior is still to verify with people (D27).

### Open bugs and risks
| ID | Sev | Summary |
|---|---|---|
| R-1 | P1 | Manual tagging of 8 items is near the 2-minute limit (F3). Spec fast autocomplete in P6 |
| R-2 | P1 | Item card VoiceOver label must be name + room + value (03 §11). Test in P1 NookUI |
| R-3 | P2 | "Save N Items" vs suggestions not yet accepted. Watch in the first builds |
| R-4 | — | No first-time-user or VoiceOver-user session yet (D27). Run with the first builds and TestFlight |
| R-5 | — | ~~D23 needs approval~~ Accepted 2026-10-04: v1.0 builds with Xcode 27 |

---

## Gate 1 — Design sign-off checklist
Gates are decided by people. This is the list for the product owner to approve.

- [x] All P0 deliverables exist: tokens (03, D24), every screen and state, illustrations (D25), app icon (`design/icon/AppIcon.appiconset`), prototype (canvas **Prototype · start here**), decisions log
- [x] Prototype tested: expert review plus automated link check (D27, substitute for hallway tests)
- [x] Open design questions closed: Capture placement (D26), every `[Inferred]` item (D28)
- [x] Assets exported: `design/illustrations/` (light, dark, accent layers), `design/icon/` (layers + app icon set)
- [x] **D23 decided:** v1.0 builds with the current release of Xcode 27; the iOS 27.1 SDK is for v1.1 only
- [x] **Gate 1 signed off** by the product owner, 2026-10-04. P0 is Done; P1 can start.
