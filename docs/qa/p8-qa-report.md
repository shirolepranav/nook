# P8 QA report — 2026-10-11
Builds: `p8/router-ai-scan` · Xcode 27.0 · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro Max, 13-inch iPad Pro (M5)

A phase close. Runs:
- **Build:** `build-for-testing` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` succeeds. The only warning is from the App Intents metadata tool ("no AppIntents.framework dependency"), which isn't from code.
- **Policy greps and tokens:** ✔. Only NookAI imports FoundationModels and Vision.
- **NookKit:** 93 ✔. New tests:
  - `v1StoreMigratesToV2` opens a P7 store (`Fixtures/stores/v1.store`) and keeps its items and room
  - `conditionRoundTrips`
- **NookAI:** 31 ✔ (1 skipped: the evaluation, below). New in `RouterTests`, 10 tests:
  - the engine choice per availability, including a model without image input
  - availability checked per task
  - an AI failure keeps what arrived and ends quietly
  - the 20 s timeout, with the input untouched
  - `fillItem` returns nil on a failure, a timeout or Classic
  - a failed AI read falls back to Classic
  - box checks and resizing

  `nameMatchingCountsSynonymsAndPlurals` tests the evaluation's scoring.
- **NookUI:** 21 ✔. Snapshots are unchanged; the suggested state is opt-in.
- **App tests:** the full suite on all three devices, with failures rerun at low load (below).
- **Screenshots** (`docs/qa/p8/`): SE in light, dark and AX5, covering:
  - C-03 streaming and settled
  - C-05 prefilled
  - S-01
  - S-11

**Status:** In QA. Accuracy and speed need a real Apple Intelligence iPhone (**Owner** rows).

Closing P8 turned up these problems, all fixed:
- **VoiceOver read "Suggested" instead of the typed name.** `.accessibilityValue` on the field replaced its text. The chip is now its own element, and the field keeps its value.
- **AX5 scan cards broke words mid-word** ("Sug-gest-ed", "Toas-ter"). At accessibility sizes a card now puts its photo and controls on top, with full-width words below.
- **The audit flagged the chip and field labels** as partial Dynamic Type support. Two causes:
  - a size cap on the chip
  - `ViewThatFits`

  Both now switch layout on `isAccessibilitySize`, as D51 found for S-07.
- **"Appliances · Good" wrapped with the dot starting a line** on the SE. Category and condition now sit on their own lines.
- **"Review Items" clipped** between Cancel and Accept All at large sizes. It's now "Review".
- **Adding S-11's row pushed S-01 past the fold,** and the audit read that as clipped text. S-01 is now grouped as on its board ("Your data", "Nook"), with "Ready" beside Apple Intelligence.
- **I-06's Clear date (P7) had a glyph-sized tap area** on the Pro Max; its 44-pt frame was outside the button.
- **The evaluation reported −100%** on the simulator, which claims the model is available but fails every request (D54). It now probes with a real request first, so it skips on simulators.
- **Test fixes:**
  - the fallback test now waits for its card before tapping Save
  - the Classic scan test scrolls to the third card on a tall phone

## Acceptance (roadmap P8)
- [x] **Router** with `SystemLanguageModel.default.availability`, checked per task: `availabilityIsCheckedPerTask`, `aiAvailabilityUsesTheAIEngine` and `classicAvailabilityUsesTheClassicEngine`.
- [x] **Vision check:** `aModelThatCantSeeImagesSendsPhotosToClassic`. S-11 tells such a model apart ("You tag items in photos yourself.").
- [x] **Room scan pipeline:**
  - resize to 1,536 px (`photosAreResizedToTheModelsSize`)
  - structured `DetectedItem` output
  - OCR and barcode tools
  - streaming
  - silent fallback on any error or the 20 s timeout (`anAIFailureKeepsWhatArrivedAndEndsQuietly`, `theTimeoutEndsAHungScanWithTheInputUntouched`, `testAIScanFailureFallsBackToTagging`)
- [x] **C-03:** outlines one by one with a tick, cards that wait for Accept, Accept All and Save all (`testAIScanSuggestsAndSavesAll`).
- [x] **C-05 prefill** marked Suggested, filling only empty fields: `testQuickAddPrefillsFromThePhoto`.
- [x] **S-11** with its four states and the switch: `testTurningOffAppleIntelligenceMakesScansManual`.
- [ ] **8 clear items → at least 6 correct (F3): Owner.** On the AI iPhone, photograph 8 everyday items on a shelf 3 times, from 1.5 m in daylight, and count the right names (05 §4).
- [ ] **First card in under 2 s; one-photo scan in under 8 s (PRD §9): Owner.** Run Instruments' Points of Interest during a scan. The router emits `firstItem` and the `photoScan` interval.
- [ ] **Evaluation numbers: Owner.** The harness and 102 labeled photos are ready (`Fixtures/eval`, D53), but no model can run on a simulator (D54). Run `xcodebuild -scheme NookAI test -only-testing:NookAITests/roomScanEvaluation` on the AI iPhone and paste the `EVAL` line into the PR.

## Phase QA
| Case | Device | Result |
|---|---|---|
| Model downloading | unit, Owner | `availability` other than `.available` → Classic; S-11 "Downloading". **Owner:** a phone mid-download |
| Apple Intelligence turned off mid-session | unit, SE | ✅ Checked per photo and task; S-11's switch makes the next scan manual |
| A model without image input | unit | ✅ Photos go to Classic, text to AI |
| Cluttered shelves | Owner | 102-photo set includes garages, a playroom, cluttered desks |
| Mirrors and screens | Owner | Instructions say to ignore reflections and screens; the set includes mirrors, a TV and reflections |
| Same item in two photos | SE | Two suggestions, never merged (D53); photos 058/059 and 120/121 in the set |
| Model available but assets missing | SE (simulator) | ✅ Every request fails, and the scan simply shows the tagging tools (D54) |

## Smoke suite
**Full app suites, first pass:**
- **SE:** 48 passed, 5 failed, 13 skipped (opt-in screenshot and perf tests)
- **Pro Max:** UI suite, 46 passed, 7 failed, 12 skipped
- **13-inch iPad:** UI suite, 52 passed, 4 failed, 9 skipped

The Mac's load reached 300–740 during the runs (StorageManagement and ReportCrash, D49 notes), and tests timed out. Every failure was rerun on its own. All pass except F3's timing test and one iPad flake, which passes on reruns.

**On the iPad:**
- `testArrangeSpots` failed twice, then passed on `main` and twice on this branch.
- `testMoveInTwoTaps`, the Move audit and `testRoomsInTheSidebar` pass on rerun.

| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | SE, Pro Max, iPad | ✅ | `ShellTests` |
| S2 | SE, Pro Max, iPad | ✅ | `testCreateARoomWithThreeSpotsInUnder30Seconds` (Pro Max on rerun) |
| S3 | SE, Pro Max, iPad | ✅ | `testAddInTwoTapsEditDeleteAndRestore` |
| S4 | SE, Pro Max, iPad | ✅ | `MoveTests` (Pro Max and iPad on rerun) |
| S5 | SE, Pro Max, iPad | ✅ | `FindTests` |
| S6 | SE, Pro Max, iPad | ✅ | `testClassicScanTagsThreeItemsAndSaves` (Pro Max after the scroll fix), receipt tap-to-drop |
| S6 (F3 timing) | SE | ❌ known | `testEightItemsTaggedUnderTwoMinutes`: the first Capture tap after launch doesn't open the menu. It's the same failure on `main` (D52), so it isn't from P8. Logged below |
| S7 | SE, Pro Max, iPad | ✅ | `WarrantyAndLendTests` |
| S8 | SE, Pro Max, iPad | ✅ | `testAIScanSuggestsAndSavesAll` (scripted model saves items); `testAIScanFailureFallsBackToTagging` (the same photo opens manual tagging); every other UI test runs with `-forceClassicEngine` |

## Accessibility (screens touched)
- **`testAIScreensPassTheAccessibilityAudit`** (C-03 with suggestions, C-05 prefilled, S-11): ✔ on the SE and Pro Max.
- **S-01:** ✔ in `testScreensPassTheAccessibilityAudit`.
- **I-06:** ✔ (the Clear date fix) on the SE and Pro Max.
- **VoiceOver:**
  - Suggested cards read the name and category, with "Suggested" as the value and Accept, Edit and Remove as actions.
  - Each outline is a button named "Box 1, Kettle".
  - Prefilled fields read their value, and the chip reads "Suggested".
- **Dynamic Type at AX5:** checked in the screenshots. S-11's large title truncates to "Apple Intell…", which is the system navigation bar (other long titles do the same).
- **Reduce Motion:** the outlines fade instead of drawing, through the existing `DetectionOverlay`.

## No-AI check
- Every UI test outside the AI path runs with `-forceClassicEngine`, and Classic C-04 is unchanged (S6 ✅).
- With the scripted model failing, the scan shows the tagging tools and no error.
- No user-facing string mentions AI, except S-11's "Apple Intelligence", which is the setting's name.
- **Owner:** run US1–US6 with Apple Intelligence off on the AI iPhone, and on an older iPhone.

## Open bugs
| ID | Sev | Summary |
|---|---|---|
| P8-1 | P2 | The first Capture tap right after launch sometimes doesn't open the menu (F3's timing test; on `main` since P6, D52). A second tap works |
| P8-2 | P3 | Run-order flakes when the Mac is loaded: `testArrangeSpots` (iPad) and the keyboard-focus taps in Room and Spot tests. They pass alone |

## Owner checks (real devices)
1. **F3 test shelf** (above).
2. **Speed budgets** (above).
3. **Evaluation run** (above): paste `run date · iOS build · device · recall · precision`.
4. **Box quality:** do the outlines land on the items?
5. **The No-AI pass** on an older iPhone.
