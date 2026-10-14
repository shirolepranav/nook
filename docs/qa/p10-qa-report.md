# P10 QA report — 2026-10-13
Builds: `p10/reports-exports` · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), 13-inch iPad Pro (M5)

This was a minimal close, following the test cadence: no full `ci.sh`, no Pro Max run, and dark screenshots only. Runs:
- **Build:** clean build, zero warnings.
- **Policy greps and tokens:** ✔. `check_tokens.py`: 0 off-token colors, 0 off-grid spacing, 0 off-scale font sizes.
- **NookKit:** 109 ✔. New tests:
  - **`ReportTests`:** room grouping and order, totals per currency, scopes (home, rooms, one item), Private items included and deleted items left out, and CSV quoting.
  - **`csvMatchesGolden`:** compares with `Fixtures/golden/home.csv`.
  - **`BackupTests`:**
    - round trip: export, wipe, restore with Replace, then every row and file compared
    - Merge adds only what's missing
    - Replace sends to Recently Deleted and revives items that are also in the backup
    - newer, broken and truncated files are refused
    - unsafe paths are refused
    - stored, deflated and Mac-made zips are read
    - a check that every model field is carried by its backup record
- **NookAI:** 44 ✔ (2 evaluations skip on the simulator, D54). New tests:
  - **`roomSummariesFallBackToNone`:** Classic, a failure and a timeout all give nil.
  - **`roomSummariesMustBeGrounded`:** rejects invented numbers, text that names no real item, and text that's too long.
  - **`RoomSummaryEvaluation`:** 10 rooms, device only.
- **App unit tests (`NookTests`):** 4 ✔.
  - `everyItemIsOnANumberedPage`: the PDF's page count equals the builder's, every page reads "Page n of N", and all 60 items are present.
  - `cancellingStopsAndRemovesTheFile`.
  - `fiveHundredItemsRenderInBudget`: **500 items, 51 pages, 0.28 s** on the SE simulator.
- **UI tests:** `ReportsTests` 6/6 ✔ on the SE and on the iPad. `testP10ScreensPassTheAccessibilityAudit` ✔ on the SE and on the iPad.
- **Screenshots** (`docs/qa/p10/`): SE in dark mode: R-01, R-02 (builder, room summaries suggested, preview), R-03, S-04 and H-06.

**Status:** In QA. Still to do: the owner's real-device checks (the **Owner** rows below) and the smoke suite S1–S9 on CI.

Closing P10 turned up these problems, all fixed:
- **The report hung at "Rendering 0 of 14".** Decoding every thumbnail at once in a task group deadlocked ImageIO's HEIC decoder on the cooperative pool. A process sample showed every task waiting in `cacheImmediately`. Thumbnails now load one at a time, and 500 still render in 0.3 s (D56).
- **The audit read the half-size report page, the label preview and the CSV row preview as app text** at a fixed size and clipped. Each is now hidden behind one labelled element: "Report page 1 of 3", "Label preview: Box 14…", "Preview of the first rows: …". A first attempt with `accessibilityRepresentation { Color.clear… }` exposed no element at all. A UI test caught that.
- **The iPad audit flagged R-02's "3 pages · 14 items · ₹4,036" line as too small to hit**, and VoiceOver read the dots aloud. It's now one line of text.
- **"Save Image" wrapped to two lines** on the SE label sheet. Share and Save Image now stack at accessibility sizes.
- **The CSV sheet audit at the medium detent** reported clipping (D45). The test raises the sheet first.

## Acceptance (roadmap P10)
- [x] **Insurance report builder and preview (R-02)**, rendered with `ImageRenderer`, grouped by room, with photos, values, serials, a receipt appendix and totals: `everyItemIsOnANumberedPage`, `testInsuranceReportOpensInQuickLook`, and the Quick Look check in the simulator (2 report pages and a receipt page).
- [x] **Optional AI room summaries:** `roomSummariesFallBackToNone`, `roomSummariesMustBeGrounded`, and the audit run with the scripted model (tinted Suggested, editable).
- [x] **Watermarked free preview:** `testFreeSeesAWatermarkedPreviewOnly` (`-uiTestingFree`; everyone is Pro until P11, D56).
- [x] **CSV export (R-03):** `csvMatchesGolden`, `testCSVExportIsReadyToShare`.
- [x] **.nookbackup create and restore (S-04):** `BackupTests` (round trip, Merge, Replace), `testCreateBackup`.
- [x] **QR box labels (H-06):** `testBoxLabelFromAContainer`.
- [x] **500-item PDF under 20 s (F9):** 0.28 s on the SE simulator. **Owner:** time it on an iPhone 15. In the app, Reports → Insurance report → Preview → Create Report, with a 500-item home (debug store `items1k` is close).
- [ ] **QR opens the correct container from the Camera app (F8): Owner.** In the app, `nook://spot/<qrID>` opens the container (`testLabelLinkOpensTheContainer`, and `simctl openurl` by hand). An unknown id shows "That box isn't in Nook anymore." Still to check: print or show a label, scan it with the **system Camera app**, and confirm Nook opens to that box. This also settles D19's `[Verify in SDK]`. If Camera won't open custom schemes, Capture → Scan barcode reads the label instead.

## Phase QA
| Case | Device | Result |
|---|---|---|
| Cancelling mid-report | unit, SE | ✅ `cancellingStopsAndRemovesTheFile`; the generating card's Cancel goes back to the preview |
| Low memory | unit | Thumbnails are 400 px and decoded one at a time; each page is drawn and released before the next. **Owner:** a 500-item home on an older iPhone |
| Printing | SE (simulator) | Quick Look's Print for the report; the label prints at its real size (`UIPrintPaper.bestPaper`). **Owner:** real paper, one label sheet and one label printer if available |
| Restoring onto a device with existing data | unit | ✅ `mergeAddsOnlyWhatIsMissing`, `replaceSendsWhatIsHereToRecentlyDeleted` |
| CSV in Numbers and Excel | golden | BOM, CRLF, RFC 4180 quoting with commas, quotes, line breaks, emoji and RTL. **Owner:** open the shared file in Numbers and Excel |
| A backup re-zipped on a Mac | unit | ✅ deflated entries are read (`Fixtures/golden/deflated.zip`) |
| A backup from a newer Nook, or not a backup | unit | ✅ refused with plain copy |
| A label for a deleted box | SE | ✅ toast "That box isn't in Nook anymore." |

## Smoke suite
| ID | iPhone SE | 13-inch iPad | Note |
|---|---|---|---|
| S1–S9 | ⏭ | ⏭ | Minimal close: left to CI on the PR |
| S10 | ✅ | ✅ | A report is made (`testInsuranceReportOpensInQuickLook`; 500 items in `fiveHundredItemsRenderInBudget`); a label's link opens Box 14 (`testLabelLinkOpensTheContainer`). The Camera app half is **Owner** |

## Accessibility
- The audit passes on R-01, R-02 (builder with summaries, preview), R-03 (raised), S-04 and H-06, on the SE and the iPad.
- Paper (the report page, the label) stays at a fixed size, because it's a document. On screen it's one labelled element.
- The builder, CSV sheet, backup screen and label sheet grow to AX5. The label's buttons stack.

## No-AI pass
- Every P10 flow runs Classic in the UI tests (`-forceClassicEngine YES`). Room summaries are hidden there, and the report is otherwise identical.
- No copy mentions AI. The summary toggle reads "Room summaries".

## Performance
| Budget | Result |
|---|---|
| 500-item PDF < 20 s (F9) | 0.28 s (SE simulator, 51 pages with photos). **Owner:** iPhone 15 |

## Open bugs
None found. Out of scope, noted for later:
- ~~Copy that names the device ("on this iPhone") said "iPhone" on iPad (01 §1.3, D29).~~ Fixed in this phase with String Catalog device variations (D57). `DeviceCopyTests` checks it on the SE and the iPad.
- A label scanned while another sheet is open can't show its container over that sheet; the system keeps the open sheet.
