# P3 QA report — 2026-10-06
Builds: `p3/items-photos` · Xcode 27.0 · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro Max (portrait and landscape), 13-inch iPad Pro (M5)
Runs:
- `scripts/ci.sh`: 0 warnings, NookKit 41 ✔, NookUI 17 ✔, NookAI 1 ✔. App tests: SE 20 ✔ (7 skipped: opt-in perf and screenshots, iPad-only shortcuts). iPad: 20 ✔ and 3 ✘ on the first run; all 3 pass on rerun after the fixes below.
- iPhone 18 Pro Max, the whole app suite: 19 ✔ and 2 ✘ on the first run. Both are flakes and pass on rerun: a keyboard flake in P2's `testFirstRunPicksRoomsAndLandsOnHome`, and an audit that took too long to finish. `testRotatingWhileSelectingKeepsTheSelection` ✔.

**Status:** In QA. Every automated check passes. The rows marked **Owner** need a real device, VoiceOver, or hands on a camera. P3 is Done once they pass and the PR is merged.

Closing P3 turned up these problems, all fixed on the branch:
- **Selection title:** "N Selected" never showed, because the room's own title won. `itemSelection` now sits inside `navigationTitle`.
- **Clipped text (audit):**
  - Card breadcrumbs were cut to one line. They now wrap to two (snapshots re-recorded).
  - Item detail's bar title over the hero was clipped. It is removed, matching the mockup.
  - The "Cover" caption couldn't grow with text size. It now hides at accessibility sizes, and VoiceOver still says "Cover".
- **Prices to VoiceOver:** they now read as words ("649 Indian rupees"), not the symbol.
- **Settings:**
  - The list had no bottom margin, so at large sizes its last rows sat under the Capture button.
  - Recently Deleted has its own section.
  - The debug-only footer is gone.
- **AX5 thumbnails:** row thumbnails and photo tiles let their placeholder glyph grow out of the frame.
- **S3 test timing:** after the simulator rebooted, S3 typed the name before the auto-focused keyboard was up. It now waits for the keyboard, which still proves the field focuses itself.
- **Room test timing:** the first keyboard on a freshly booted simulator takes about 6 s, so S2's 5 s wait was too tight. It is now 10 s; F1's 30 s budget is unchanged.

## Acceptance (roadmap P3)
- [x] **A photo-and-name item saves in 2 taps (F2).**
  - `testAddInTwoTapsEditDeleteAndRestore`: Capture → Add item → shutter (tap 1) → type the name in the focused field → Save (tap 2).
  - The simulator uses the fixture camera (`-uiTestingCameraFixture`, D37); the real system camera is an **Owner** check.
  - Unit test: `aPhotoAndANameMakeAnItem`.
- [ ] **A 1,000-item grid scrolls at 120 fps on ProMotion with no dropped frames (PRD §9). Owner.**
  - `GridScrollPerfTests` (opt-in, `TEST_RUNNER_RUN_PERF=1`) seeds 1,000 items with photos and flings the grid. It runs to completion on the simulator, but the simulator reports no scroll-hitch metrics.
  - Measure on a ProMotion iPhone with Instruments (Animation Hitches), opening Storage from `-uiTestingStore items1k`. The budget is zero hitches at 120 Hz.
  - Thumbnails come from the 400-px cache (`BlobStore.thumbnail`, an NSCache of decoded images); cards are in a `LazyVGrid`.
- [x] **Item editor (I-02) with every F2 field except the warranty (D39) and the 500 common items autocomplete.**
  - Fields: photos (up to 10), name with suggestions, where, category, tags, quantity, brand, model, serial, barcode, purchase date, price and currency, store, receipt, notes, Private.
  - `common-items.json` has 500 items across 19 categories. Tests: `suggestionsStartAtTheFirstLetterAndMatchAnyWord`, `pastNamesComeFirstWithoutDuplicates`.
- [x] **Item detail (I-01) with the zoom transition.** Seen in the simulator, mid-zoom from the card. Under Reduce Motion the system cross-fades (D43).
- [x] **Photo viewer (I-03):** pinch, double-tap, swipe down, Set as Cover, Share and Delete Photo with Undo. Tests: `setCoverAndRemovePhoto`, `undoingASpotDeleteKeepsItsPhoto` (D35).
- [x] **Receipts as image or PDF (I-07)**, in Quick Look (D42). Test: `pdfReceiptsKeepTheirFileAndGetAThumbnail`.
- [x] **Photos as HEIC on disk with cached 400-px thumbnails (PRD §8).** Tests: `photosAreSavedAsHEICWithASmallThumbnail`, `photosAreStoredUpright`, `hugePhotosAreScaledDown`.
- [x] **Private flag stored.** It shows a lock badge and pill and can be set in bulk. Lock behavior is P12. Test: `tagsAndPrivateApplyToASelection`.
- [x] **Hide values.** The eye on Home masks the total and every price; it already existed as a setting (S-06, D28).
- [x] **Recently Deleted for 30 days (S-08).** Tests: `deletedItemsWaitInRecentlyDeletedAndComeBack`, `thePurgeRemovesItemsAndFilesAfter30Days` (fake clock), `testAddInTwoTapsEditDeleteAndRestore`.
- [x] **Multi-select (I-08)** with Tag, Private and Delete; Move comes in P4. Tests: `testSelectTwoDeleteAndUndo`, `testRotatingWhileSelectingKeepsTheSelection`.

## Phase QA
| Case | Device | Result |
|---|---|---|
| 10 photos per item | unit | ✅ `tenPhotosAtMost`. The 11th is refused, and the picker offers only what's left out of 10 |
| Huge PDFs | unit, SE | ✅ PDFs are copied as-is, never decoded whole. The first page becomes the thumbnail, and Quick Look pages through the rest. **Owner:** open a 200-page PDF receipt on a device |
| Camera denied | SE | ✅ With the camera denied or missing (every simulator), Add Item opens the editor with "Choose from Photos" and "Camera is off. Turn it on in Settings." **Owner:** deny it on a device and check the Settings link |
| Low storage | unit | ✅ A failed write throws `writeFailed`, the editor keeps the draft and says "Couldn't save right now. Your items are safe on this device.", and the context rolls back. **Owner:** fill a device's disk and try |
| Emoji and right-to-left names | unit | ✅ `emojiAndRightToLeftNamesWork`. **Owner:** an Arabic or Hebrew name on a card in an RTL language |
| Killing the app mid-edit | unit | ✅ Files are written when picked (D40). An item exists only after Save, and `theSweepRemovesOnlyOldOrphans` cleans up the files of a killed edit at the next launch. The draft itself is lost, by design |
| Room or spot deleted with items in it (D28) | unit, SE | ✅ `deletingARoomRehomesItsItemsAndUndoesInOneStep`, `testDeleteARoomWithItemsSendsThemToRecentlyDeleted` |
| Discard changes | SE, iPad | ✅ `testCancelWithChangesAsksToDiscard` |
| Moves write history (D38) | unit | ✅ `aMoveWritesOneEventAndASameplaceMoveWritesNone` |
| Rotate Pro Max while selecting (D35 trap) | Pro Max | ✅ `testRotatingWhileSelectingKeepsTheSelection` |

## Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | iPhone SE (sim) | ✅ | `ShellTests` |
| S1 | iPhone 18 Pro Max (sim) | ✅ | |
| S1 | 13-inch iPad (sim) | ✅ | ⌘1–⌘4; `testRoomsInTheSidebar` failed once (⌘E) and passed on rerun |
| S2 | iPhone SE (sim) | ✅ | Wait for the first keyboard raised to 10 s (see above) |
| S2 | iPhone 18 Pro Max (sim) | ✅ | |
| S2 | 13-inch iPad (sim) | ✅ | |
| S3 | iPhone SE (sim) | ✅ | `testAddInTwoTapsEditDeleteAndRestore` |
| S3 | iPhone 18 Pro Max (sim) | ✅ | |
| S3 | 13-inch iPad (sim) | ✅ | |
| S3 | Real iPhone | **Owner** | Same flow with the real camera (D37): the permission prompt, then the shutter, then Save |

## Accessibility (screens touched: H-01, H-02, H-03, I-01, I-02, I-03, I-07, I-08, S-01, S-08)
- [x] **Accessibility audit:** `testItemScreensPassTheAccessibilityAudit` covers Home with items, Room, selection, Item detail, the editor and Recently Deleted. It passes on the SE, the Pro Max and the iPad, and the P1/P2 audits still pass.
  - Exceptions added, each commented in the test: a one-line text field scrolls instead of clipping, and the iPad floating bar's element-less clipped-text issues join its existing exception.
- [x] **VoiceOver labels:**
  - cards: "Espresso machine, Kitchen → Counter, 649 Indian rupees, Private"
  - "selected" / "not selected" in selection mode
  - "Photos, 2 of 10", with Set as Cover, Move Left/Right and Delete Photo as custom actions
  - Where reads "Kitchen, Counter"
  - Recently Deleted rows offer Restore and Delete Now actions
  - the hero reads "Photo 1 of 3. Open photo viewer"
- [x] **Accessibility sizes:** grids become rows (`ItemRow`), detail rows stack, and thumbnails keep their size. `Items` snapshots cover AX5.
- [ ] **Owner:**
  - VoiceOver through S3 on a device
  - a 1,000-item room with VoiceOver on: XCUITest's accessibility snapshot of that grid times out (the perf test avoids queries for this reason), so check that VoiceOver stays responsive
- [x] **Screenshots:** light, dark and AX5 on the SE and the iPad, from `ScreenshotTests.testP3Screens` (opt-in, `TEST_RUNNER_RUN_SCREENSHOTS=1`), reviewed one by one. Three problems they caught are fixed:
  - In selection mode, Room's own Add and More buttons crowded out "N Selected". They now hide while selecting.
  - At AX5, item detail's category and price squeezed side by side ("Appli-ances"). They now stack.
  - The editor's wrapped Where and Category values were centered. They are now leading-aligned.
- [ ] **Owner:** in dark mode, the accent "Edit" label on the glass bar over a light photo has weak contrast (`SE-I-01-dark`). The system glass adapts to the photo, so check it with real photos on a device.

| Screen | iPhone SE | 13-inch iPad (portrait) |
|---|---|---|
| H-01 Home with items | [light](p3/SE-H-01-light.jpg) · [dark](p3/SE-H-01-dark.jpg) · [ax5](p3/SE-H-01-ax5.jpg) | [light](p3/iPad-H-01-light.jpg) · [dark](p3/iPad-H-01-dark.jpg) · [ax5](p3/iPad-H-01-ax5.jpg) |
| H-02 Room with items | [light](p3/SE-H-02-light.jpg) · [dark](p3/SE-H-02-dark.jpg) · [ax5](p3/SE-H-02-ax5.jpg) | [light](p3/iPad-H-02-light.jpg) · [dark](p3/iPad-H-02-dark.jpg) · [ax5](p3/iPad-H-02-ax5.jpg) |
| I-08 Multi-select | [light](p3/SE-I-08-light.jpg) · [dark](p3/SE-I-08-dark.jpg) · [ax5](p3/SE-I-08-ax5.jpg) | [light](p3/iPad-I-08-light.jpg) · [dark](p3/iPad-I-08-dark.jpg) · [ax5](p3/iPad-I-08-ax5.jpg) |
| I-01 Item detail | [light](p3/SE-I-01-light.jpg) · [dark](p3/SE-I-01-dark.jpg) · [ax5](p3/SE-I-01-ax5.jpg) | [light](p3/iPad-I-01-light.jpg) · [dark](p3/iPad-I-01-dark.jpg) · [ax5](p3/iPad-I-01-ax5.jpg) |
| I-02 Item editor | [light](p3/SE-I-02-light.jpg) · [dark](p3/SE-I-02-dark.jpg) · [ax5](p3/SE-I-02-ax5.jpg) | [light](p3/iPad-I-02-light.jpg) · [dark](p3/iPad-I-02-dark.jpg) · [ax5](p3/iPad-I-02-ax5.jpg) |
| I-03 Photo viewer | [light](p3/SE-I-03-light.jpg) · [dark](p3/SE-I-03-dark.jpg) · [ax5](p3/SE-I-03-ax5.jpg) | [light](p3/iPad-I-03-light.jpg) · [dark](p3/iPad-I-03-dark.jpg) · [ax5](p3/iPad-I-03-ax5.jpg) |
| S-08 Recently Deleted (empty) | [light](p3/SE-S-08-light.jpg) · [dark](p3/SE-S-08-dark.jpg) · [ax5](p3/SE-S-08-ax5.jpg) | [light](p3/iPad-S-08-light.jpg) · [dark](p3/iPad-S-08-dark.jpg) · [ax5](p3/iPad-S-08-ax5.jpg) |


## No-AI check
n/a: the router isn't touched. Every P3 path is Classic. Quick add with the camera off goes straight to the editor.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | Undo after editing an item restores its fields but not photos removed in that edit (`ItemService.write`, ponytail note). Cancel is the way back before Save. |
| — | P3 | The system camera (D37) has no "Skip photo" or "Choose from Photos" buttons; Cancel closes it. P6's own camera adds them. |
| — | P3 | XCUITest can't snapshot a room with about 1,000 cards (query timeout). VoiceOver responsiveness on a huge room is an **Owner** check above; P13's performance pass should look at it. |
| — | P3 | A delete can be undone but not redone (D35, carried over). |
