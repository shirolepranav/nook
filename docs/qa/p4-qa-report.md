# P4 QA report — 2026-10-06
Builds: `p4/move-history` · Xcode 27.0 · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro Max, 13-inch iPad Pro (M5)
Runs:
- **Build:** clean, 0 warnings. Policy greps and `check_tokens.py` pass.
- **NookKit:** 46 ✔ (`swift test`), 5 of them new `LocationService` tests.
- **App suite:** 33 tests on each device, 0 failures on the first run of each.
  - Skipped: the opt-in perf and screenshot tests, plus the iPad-only shortcut tests on iPhone (SE 8, Pro Max 7, iPad 5).
  - Includes the 4 new `MoveTests` and `testRotatingWhileSelectingKeepsTheSelection` on the Pro Max (D35).
- **After the iPad fix below:** `MoveTests` (now 5, with ⇧⌘M) and the Move audit were rerun on the SE and the iPad. All pass.

**Status:** In QA. Every automated check passes. The **Owner** rows below need a device.

Closing P4 turned up these problems, all fixed on the branch:
- **The picker was a bottom sheet on iPad.**
  - A medium detent overrides `.presentationSizing(.form)`, and a sheet's content reads a compact size class even in a wide window.
  - RootView now passes the window's size class down (`windowSizeClass`), and the medium detent is iPhone-only. On iPad the picker is a centered form sheet (D29, D45).
- **The room glyph outgrew its 32-pt circle at AX5.** It's now capped at xxLarge, the same fix as P3's thumbnails.
- **The audit flagged false clipping on the medium sheet.** A medium-height sheet is drawn slightly scaled, and the auditor then flags the List's own section header. The audit now runs at full height. The search field's clipping is exempt, like a plain text field (D45).
- **The P4 screenshot test** tapped an ambiguous Cancel (the picker's and the selection's were both on screen).

## Acceptance (roadmap P4)
- [x] **Moving one item takes 2 taps (F6).** `testMoveInTwoTapsShowsInHistoryAndUndoes`: Move (tap 1), then a Recent row (tap 2). The toast and the history row confirm it. Adding an item records an event, so a new item already has recents (D44).
- [x] **Move picker (I-04) with the last 5 locations,** then rooms → spots → containers, with search.
  - `recentsAreNewestFirstDistinctLiveAndSkipTheCurrentPlace` covers the order, duplicates, the limit, deleted places and the current place.
  - Search matches without regard to case or accents (`localizedStandardContains`).
- [x] **Multi-item move.** `testMoveTwoSelectedItems` (I-08 bar), `aMoveRecordsTheRoomAndSourceAndSkipsItemsAlreadyThere`.
- [x] **LocationEvent recording with source.** From, to, `toRoomID`, source (`manual`, `found`), date. Tests: `aMoveRecordsTheRoomAndSourceAndSkipsItemsAlreadyThere`, `aMoveWritesOneEventAndASameplaceMoveWritesNone`.
- [x] **Location history (I-05).** `historyIsNewestFirstAndOutlivesTheSpot`, and the UI test's check for "Moved by you" and "Added".
- [x] **Last confirmed date.** Every move sets `lastConfirmedAt`, and I-01 shows it (unit tests above).
- [x] **"Found it here instead".** `testFoundItHereInsteadReadsAsFoundInHistory`: the picker asks "Where did you find it?", the toast says "Found in Garage → Metal shelf.", and history reads "Found here by you".
- [x] **Also wired:**
  - the Move item in the card context menu
  - ⇧⌘M (`testShiftCommandMOpensMove`, iPad)
  - the editor's Where row, which uses the picker to fill the field only (D38's menu is gone)
  - Move Container on H-03 (D44)

## Phase QA
| Case | Device | Result |
|---|---|---|
| Moving containers with items inside | unit, SE, iPad | ✅ `movingAContainerCarriesItsItemsWithOneEventEach`, `testMoveAContainerCarriesItsItems`: each item gets the new room and its own event |
| Moving into a container | unit, SE | ✅ The picker lists containers under their spot. `recents…` moves into Box 14. A container can't go into a container (`containerTooDeep`) |
| Undo after move | unit, SE, Pro Max, iPad | ✅ The toast's Undo restores the place and removes the event across a save (`undoTakesASavedMoveBackAndDropsItsEvent`, D45). **Owner:** ⌘Z with a hardware keyboard, and shake on a device |
| History after deleting a spot | unit | ✅ `historyIsNewestFirstAndOutlivesTheSpot`: paths are text. Recents drop the deleted spot |
| Moving to where it already is | unit, SE | ✅ The current place shows "Here now" and is disabled. A no-op move writes nothing and shows no toast |
| Multi-select that's all in one place | SE | ✅ That place is marked "Here now". A mixed selection marks nothing |
| Rotate the Pro Max while selecting (D35 trap) | Pro Max | ✅ `testRotatingWhileSelectingKeepsTheSelection` |
| 50+ rooms in the picker | reasoned | ✅ The picker is a lazy `List` with one row per room. **Owner:** scroll it with `-uiTestingStore many` on a device |

## Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | iPhone SE (sim) | ✅ | `ShellTests` |
| S1 | iPhone 18 Pro Max (sim) | ✅ | |
| S1 | 13-inch iPad (sim) | ✅ | ⌘1–⌘4 |
| S2 | iPhone SE (sim) | ✅ | `testCreateARoomWithThreeSpotsInUnder30Seconds` |
| S2 | iPhone 18 Pro Max (sim) | ✅ | |
| S2 | 13-inch iPad (sim) | ✅ | |
| S3 | iPhone SE (sim) | ✅ | `testAddInTwoTapsEditDeleteAndRestore` |
| S3 | iPhone 18 Pro Max (sim) | ✅ | |
| S3 | 13-inch iPad (sim) | ✅ | |
| S4 | iPhone SE (sim) | ✅ | `testMoveInTwoTapsShowsInHistoryAndUndoes` |
| S4 | iPhone 18 Pro Max (sim) | ✅ | |
| S4 | 13-inch iPad (sim) | ✅ | Rerun after the form-sheet fix |
| S4 | Real iPhone | **Owner** | Move in 2 taps and the success haptic (03 §10) |

## Accessibility (screens touched: I-01, I-02, I-04, I-05, I-08, H-03)
- [x] **Accessibility audit:** `testMoveScreensPassTheAccessibilityAudit` covers the picker, its room page and history, on the SE and the iPad. The P1–P3 audits still pass on all three devices.
- [x] **VoiceOver labels:**
  - picker rows read as "Garage, Metal shelf", with "Here now" as the value for the current place
  - the room glyph is hidden from VoiceOver
  - each history row is one element: "October 6, 2026. Garage. From Kitchen, Counter. Moved by you."
  - I-01's Move and Found It Here Instead stay reachable. The card text keeps its combined label
- [x] **Accessibility sizes:** picker rows wrap, the glyph stays in its circle, and I-01's two buttons stack. History wraps with no truncation.
- [x] **Reduce Motion:** the location card's change uses `NookMotion.settle`, which fades under Reduce Motion.
- [ ] **Owner:**
  - VoiceOver through S4 on a device
  - the success haptic on a move
- [x] **Screenshots:** light, dark and AX5 on the SE and the iPad (portrait), from `ScreenshotTests.testP4Screens` (opt-in), reviewed one by one.

| Screen | iPhone SE | 13-inch iPad (portrait) |
|---|---|---|
| I-04 Move picker | [light](p4/SE-I-04-light.jpg) · [dark](p4/SE-I-04-dark.jpg) · [ax5](p4/SE-I-04-ax5.jpg) | [light](p4/iPad-I-04-light.jpg) · [dark](p4/iPad-I-04-dark.jpg) · [ax5](p4/iPad-I-04-ax5.jpg) |
| I-04 Move, 2 items | [light](p4/SE-I-04-many-light.jpg) · [dark](p4/SE-I-04-many-dark.jpg) · [ax5](p4/SE-I-04-many-ax5.jpg) | [light](p4/iPad-I-04-many-light.jpg) · [dark](p4/iPad-I-04-many-dark.jpg) · [ax5](p4/iPad-I-04-many-ax5.jpg) |
| I-04 Moved, with Undo | [light](p4/SE-I-04-moved-light.jpg) · [dark](p4/SE-I-04-moved-dark.jpg) · [ax5](p4/SE-I-04-moved-ax5.jpg) | [light](p4/iPad-I-04-moved-light.jpg) · [dark](p4/iPad-I-04-moved-dark.jpg) · [ax5](p4/iPad-I-04-moved-ax5.jpg) |
| I-05 Location history | [light](p4/SE-I-05-light.jpg) · [dark](p4/SE-I-05-dark.jpg) · [ax5](p4/SE-I-05-ax5.jpg) | [light](p4/iPad-I-05-light.jpg) · [dark](p4/iPad-I-05-dark.jpg) · [ax5](p4/iPad-I-05-ax5.jpg) |

## No-AI check
n/a: the router isn't touched. Every P4 path is manual. The `siri` and `ai` sources only have history copy, ready for P9 and P12.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | When an item's only recent is where it already is (a brand-new user's first item), Recent is empty and the move takes 3 taps (Move → room → spot). F6's 2 taps hold once any other place has been used. |
| — | P3 | Turning a container into a spot (H-05) changes the paths of the items in it without a history entry. Their room and spot are unchanged, so it isn't a move. |
| — | P3 | History shows names as they were at the time of each move, so a renamed room keeps its old name there. This is by design (PRD §6: history is a record). |
