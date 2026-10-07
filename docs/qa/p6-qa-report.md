# P6 QA report — 2026-10-07
Builds: `p6/classic-capture` · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), 13-inch iPad Pro (M5)
Runs (a reduced close, like P5: no full `scripts/ci.sh`, light-mode screenshots only, no Pro Max run):
- **Build:** `build-for-testing` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`: clean, 0 warnings.
- **Policy greps and tokens:** `policy-check.sh` ✔ (no Vision or VisionKit outside NookAI); `check_tokens.py` ✔.
- **NookKit:** 74 ✔ (`swift test`), 3 new: scanned receipt text saved and found by search, a room-scan photo keeps its box, `item(withBarcode:)`. Search budget on an optimized build: slowest keystroke 11 ms at 5,000 items.
- **NookAI:** 19 ✔ on the SE: `ReceiptParserTests` (36 cases), `SerialAndEANTests`, `ReceiptFixtureTests`, and the sticker fixture.
- **NookUI:** 21 ✔, with new `DetectionOutline`, `ScanHighlight` and `ShutterButton` snapshots in all 5 variants (light, dark, both AX5, light Increase Contrast). `CameraControl` is Liquid Glass, so it's checked in the gallery instead.
- **App, iPhone SE:** `NookTests`, `CaptureTests` (8), `ShellTests`, `OnboardingTests`, `RoomTests`, `ItemTests`, `MoveTests`, `FindTests` and `AccessibilityAuditTests`. Everything passes except P5's two known audit findings (below).
- **App, 13-inch iPad:** `CaptureTests` (8) and `ShellTests` (6) ✔. The manual barcode test first failed only because the iPad simulator shows no software keyboard; the test now taps the field.
- **Load note:** most runs happened while the Mac was at a load average of 100–200 (`ReportCrashService` handling simulator crash reports), so UI-test times are pessimistic.

**Status:** In QA. The **Owner** rows need a real device: the camera, document scanner, barcode scanner and share sheet don't exist on the simulator.

Closing P6 turned up these problems, all fixed:
- **C-04 on the SE: the name field was hidden** under the keyboard and the Save bar. Naming now takes Save's place in the bottom inset, right above the keyboard. The photo takes 45% of the height that's left, so it shrinks while typing, and the panel's Cancel is a corner ✕.
- **C-06: neighbouring highlights' 44 pt tap areas overlapped,** so tapping the total filled the tax. One tap layer now picks the nearest highlight; each highlight is still a VoiceOver button (D48).
- **The fixture camera's feed made the stage wider than the screen,** which pushed Done off the edge.
- **The sticker reader opened blank.** `SinglePhotoCamera` made its camera in `onAppear` on an empty `Group`, which never appears; it now makes it in `init`.
- **Receipt fixtures:** rotated receipts lost the pairing of "TOTAL" and its number; rows now come from Vision's quadrilaterals with the tilt taken out. A dropped ¥ left whole totals unread; whole numbers count on a TOTAL row.
- **Accessibility:** the receipt photo is now an element that reads its recognized text; the photo counter isn't drawn before the first photo; the "Saving to" pill wraps.

## Acceptance (roadmap P6)
- [x] **Manual path saves 8 items in under 2 minutes (F3).** `testEightItemsTaggedUnderTwoMinutes` times it from Capture to the "8 items saved." toast: 68 s on the SE under normal load, and 78–117 s while the Mac was overloaded. On the iPad: 49 s. That's about 16 actions plus typing.
- [x] **Capture menu (C-01):** all four rows work, with the room or spot as context. ⇧⌘N and "Scan This Room/Spot" in the empty states open C-02.
- [x] **Room scan camera (C-02):** soft ask, coach hint (first scan, Tips, low light), shutter, counter, Done, and "Saving to" through the Move picker. Camera denied → Photos and Settings (`testCameraDeniedOffersPhotos`). No camera → Photos straight into C-04.
- [x] **Manual tagging (C-04):** tap or draw a box, name suggestions with the category filled, Accept / Edit / Remove, Accept All, Save all with Undo (`testClassicScanTagsThreeItemsAndSaves`). Add Item by Name for VoiceOver.
- [x] **Quick add (C-05):** Nook's camera with Choose from Photos and Skip photo (`ItemTests.testAddInTwoTapsEditDeleteAndRestore`, `testCancelWithChangesAsksToDiscard`).
- [x] **Receipt scan (C-06):** Vision text recognition and tap-to-drop (`testReceiptTapToDropFillsPriceAndDate`). Files, Photos and Open in Nook (`testOpenInNookShowsReceiptReview`). The text is saved for search (`scannedReceiptTextIsSavedAndFindable`).
- [x] **Barcode scanner (C-07):** fills the editor; from C-01, "You have this" or a new item (`testBarcodeFillsEditor`). Manual entry without a scanner (`testBarcodeManualEntryWhenScannerIsOff`).
- [x] **Serial sticker reader (C-08):** recognized lines listed and labeled; a tap fills Serial (`testSerialPickLineFillsField`).
- [x] **Just-in-time camera permission (D15):** the soft ask, then the system prompt; denied shows Photos and Settings.

## Phase QA
| Case | Device | Result |
|---|---|---|
| Several currencies | unit, fixtures | ✅ $, €, £, ¥, ₹/Rs., ISO codes; decimal commas, thousands separators, Indian lakh grouping. *Known:* a printed ₹ is often read as 7 or 2 (D48) |
| Date formats | unit, fixtures | ✅ US, EU and ISO numerals, 2-digit years, written months; future dates and times rejected |
| Crumpled and faded receipts | fixtures | ✅ Hard set (rotated, faded, noisy): 20 of 21 totals, 21 of 21 dates (bar: 80%). Miss: the rotated French receipt picks its VAT line |
| Low light | Owner | The hint reads ISO against the format's maximum; needs a dark room |
| Blurry photos | Owner | No blur detection (D48, ponytail); P8 can judge framing |
| Camera denied | SE, iPad | ✅ `testCameraDeniedOffersPhotos`; quick add opens the editor with Photos (D37) |
| Interruptions (a phone call) | Owner | "Camera paused", then it resumes with the photos kept (D49) |
| Share sheet → Nook | SE, iPad (simulated) | ✅ `testOpenInNookShowsReceiptReview`. **Owner:** from Photos and from Files on a device |
| iPad window resized mid-tagging | iPad | The tags live in the screen's `@State` model, so a size change keeps them. **Owner:** drag the window edge |

## Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | iPhone SE (sim) | ✅ | `ShellTests` (4), `testScreensPassTheAccessibilityAudit` |
| S1 | 13-inch iPad (sim) | ✅ | `ShellTests` (6), including ⌘1–⌘4 and the sidebar in landscape |
| S2 | iPhone SE (sim) | ✅ | `testCreateARoomWithThreeSpotsInUnder30Seconds` |
| S3 | iPhone SE (sim) | ✅ | `testAddInTwoTapsEditDeleteAndRestore` (now Nook's camera) |
| S4 | iPhone SE (sim) | ✅ | `MoveTests` (4) |
| S5 | iPhone SE (sim) | ✅ | `FindTests` (5) |
| S6 | iPhone SE (sim) | ✅ | `testClassicScanTagsThreeItemsAndSaves`, `testReceiptTapToDropFillsPriceAndDate` |
| S6 | 13-inch iPad (sim) | ✅ | Same tests |
| S1–S6 | iPhone 18 Pro Max (sim) | ⏭ | Not run (reduced close, as in P5) |
| S6 | Real iPhone | **Owner** | A real room scan, document scan, barcode and sticker |

## Accessibility (screens touched: C-01, C-02, C-04, C-05, C-06, C-07, C-08, I-02)
- [x] **Accessibility audit:** `testCaptureScreensPassTheAccessibilityAudit` passes on C-02, C-04 with a tag, C-06, C-08, camera off and C-07 typing. C-01 isn't audited: a medium-only sheet is drawn scaled and the audit calls its rows clipped (D45). I-02 with the new scan buttons passes in `testItemScreensPassTheAccessibilityAudit` up to I-01.
- [ ] **Still open from P5 (owner's choice):** I-01 tag chips ("Potentially inaccessible text") and the Find footer (Dynamic Type). Same failures as P5; nothing new.
- [x] **VoiceOver labels:** boxes read "Box 2, Lamp"; tag cards read "name, category" with Accepted/Not accepted and actions Accept, Edit, Remove; highlights read "Amount $766.41" / "Date 09/14/2026"; the receipt photo reads its text; the counter reads "1 photo taken".
- [x] **No camera, no drawing:** Add Item by Name; Pick from Photos everywhere; typed barcodes; "Enter it myself" for serials.
- [x] **Reduce Motion:** outlines fade instead of drawing on (`DetectionOutline`); the shutter fades instead of shrinking; haptics stay.
- [ ] **Owner:** VoiceOver through S6 on a device; AX5 on C-04 (cards as one column).
- [x] **Screenshots:** light only, on the SE and the 13-inch iPad (portrait), from `ScreenshotTests.testP6Screens` (opt-in).

| Screen | iPhone SE | 13-inch iPad (portrait) |
|---|---|---|
| C-01 Capture menu | [light](p6/SE-c-01-capture-menu.jpg) | [light](p6/iPad-c-01-capture-menu.jpg) |
| C-02 Room scan | [light](p6/SE-c-02-room-scan.jpg) | [light](p6/iPad-c-02-room-scan.jpg) |
| C-02 Camera off | [light](p6/SE-c-02-camera-off.jpg) | [light](p6/iPad-c-02-camera-off.jpg) |
| C-04 Naming | [light](p6/SE-c-04-naming.jpg) | [light](p6/iPad-c-04-naming.jpg) |
| C-04 Manual tagging | [light](p6/SE-c-04-manual-tagging.jpg) | [light](p6/iPad-c-04-manual-tagging.jpg) |
| C-04 Saved | [light](p6/SE-c-04-saved-toast.jpg) | [light](p6/iPad-c-04-saved-toast.jpg) |
| C-06 Receipt review | [light](p6/SE-c-06-receipt-review.jpg) | [light](p6/iPad-c-06-receipt-review.jpg) |
| C-06 Receipt filled | [light](p6/SE-c-06-receipt-filled.jpg) | [light](p6/iPad-c-06-receipt-filled.jpg) |
| C-07 Type it | [light](p6/SE-c-07-type-it.jpg) | [light](p6/iPad-c-07-type-it.jpg) |
| C-08 Sticker lines | [light](p6/SE-c-08-sticker-lines.jpg) | [light](p6/iPad-c-08-sticker-lines.jpg) |

## No-AI check
✅ P6 is the Classic path; nothing touches Foundation Models. Every capture flow finishes on the simulator, which has no camera, through the fixture camera, Photos, Files or typing. No copy mentions AI. The router arrives in P8 and replaces the two `NookAI.classic` calls (D48).

## Owner device checks
1. **Low light:** scan in a dim room; "It's a little dark…" shows, and goes once the torch is on.
2. **Phone call during a scan:** take 2 photos, take a call, hang up; "Camera paused", then it resumes with 2 photos.
3. **Document camera:** scan a crumpled receipt, a faded one and a 2-page one; check the highlights and the PDF in I-07 (Live Text selectable, D49).
4. **Share sheet:** Photos → Share → Nook, and Files → Share → Nook; the review opens.
5. **Barcode:** a real EAN-13 with the torch on; the light tap and the field fill. Scan it again from C-01 → "You have this".
6. **Serial sticker:** a real appliance sticker; check the ranking.
7. **Camera denied:** Settings → Nook → Camera off; Scan room shows Photos and Settings.
8. **iPad:** resize the window mid-tagging; the tags stay.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | The two P5 accessibility audits (I-01 tag chips, Find footer). |
| — | P3 | A printed ₹ is often read as a 7 or 2, so a ₹ total can be off by a leading digit. The user taps or types it (D48). |
| — | P3 | On compact, the 5-second "Saved" toast sits over the Capture button. |
| — | P3 | No blur detection in the coach hint (D48, ponytail). |

## Follow-ups
- Real receipt photos in `Fixtures/receipts/real/` with their JSON (D48).
- Blur detection, if P8's model doesn't cover framing.
- `PhotoViewer.swift` says spot photos "arrive with room scans (P6)"; no flow sets a spot photo yet.
