# P2 QA report — 2026-10-06
Builds: `p2/close` (stacked on PRs #25–#32) · Xcode 27.0 · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro Max (portrait and landscape), 13-inch iPad Pro (M5)
Runs: `scripts/ci.sh` passes (0 warnings; app tests: SE 15 ✔ / 4 skipped for wide layouts, iPad 18 ✔ / 1 skipped); iPhone 18 Pro Max 18 tests, 0 failures, 3 skipped (iPad-only shortcuts, opt-in launch perf)

**Status:** In QA. Every automated check passes. The rows marked **Owner** need hands on a device or VoiceOver. P2 is Done once they pass and PRs #25–#33 are merged.

Closing P2 turned up six iOS 27 problems that the earlier P2 PRs shipped with. All are fixed in #31 and recorded in D35:
- Undo after deleting a room did nothing.
- Only the first of three spots was kept when typing them with Return (F1). After the first fix for that, fast typing could still lose or reorder letters ("Closet" saved as "Coset"). S2 now passes 8 runs in a row.
- Two text fields had no VoiceOver label.
- Room tabs showed in the iPhone tab bar.
- After the first fix for that, the app crashed when a regular-width iPhone rotated to portrait with a room selected.

## Acceptance (roadmap P2)
- [x] **Models are sync-ready from the start** (every property optional or defaulted, optional relationships with inverses, no unique constraints). `SchemaTests.entityIsCloudKitSafe` checks all 8 entities, and `schemaHasEveryEntity` checks the set.
- [x] **Create a room with 3 spots in under 30 seconds (F1).** `testCreateARoomWithThreeSpotsInUnder30Seconds` types a room and 3 spots with Return and asserts under 30 s. It passes on the SE, 18 Pro Max and 13-inch iPad. `threeSpotsTakeFourCalls` covers the service.
- [x] **Home with room cards (H-01), Room (H-02), Spot and container (H-03), editors (H-04, H-05), Arrange rooms (H-07), onboarding (O-01, O-02).** UI tests: `testFirstRunPicksRoomsAndLandsOnHome`, `testAddContainersOnTheFloorAndInsideASpot`, `testArrangeRooms`, `testArrangeSpots`, `testRoomsInTheSidebar`, `testDeleteARoomAndUndo`.

## Phase QA
| Case | Device | Result |
|---|---|---|
| Nesting limit: containers one level deep (D3, D34) | unit | ✅ `containersSitInARoomOrASpotButNotInAContainer`, `containersMoveAndSpotsChangeKindWithinTheRules` |
| Deleting rooms with content | unit, SE | ✅ `roomsWithItemsCantBeDeleted` (D28). `deletingARoomDeletesItsSpotsAndContainersButNotItsItems`. Undo brings back the room, spots, containers and QR ids after a save (`undoingASavedDeleteBringsTheRoomBack`, `testDeleteARoomAndUndo`) |
| 50+ rooms | SE | ✅ `testManyRoomsAndLongNames`: 55 rooms scroll on Home and the last one opens |
| Long names | SE | ✅ Same test: a 57-character room and a 60-character spot open and are found by their full names |
| Reordering rooms and spots | SE, Pro Max, iPad | ✅ Drag in `testArrangeRooms` and `testArrangeSpots`; order kept (`roomsKeepTheirOrder`, `spotsKeepTheirOrder`) |
| VoiceOver room reordering | — | **Owner:** with VoiceOver on, open Arrange Rooms, swipe up/down on a room for **Move Up / Move Down**, check the "moved to position N of M" announcement, then Done. The actions exist and pass the audit, but no test drives VoiceOver itself. |
| Regular width: rooms in the sidebar, ⌘E edits the selected room | iPad, Pro Max landscape | ✅ `testRoomsInTheSidebar`. ⌘E is checked on iPad only (D29); menu shortcuts don't fire on iPhone. |
| Rotate Pro Max to portrait with a room selected | Pro Max | ✅ Fixed (D35): returns to Home, no crash |

## Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | iPhone SE (sim) | ✅ | `ShellTests`; the tab bar now shows only Home, Find, Reports and Settings (`testArrangeRooms` asserts no room tabs) |
| S1 | iPhone 18 Pro Max (sim) | ✅ | Sidebar in landscape; tab bar in portrait |
| S1 | 13-inch iPad (sim) | ✅ | Sidebar; ⌘1–⌘4 |
| S1 | Resized iPad window | **Owner** | As in P1: narrow it in Stage Manager. It switches to the tab bar, keeps the tab, and a selected room falls back to Home (D35) |
| S2 | iPhone SE (sim) | ✅ | Room with 3 spots, under 30 s |
| S2 | iPhone 18 Pro Max (sim) | ✅ | |
| S2 | 13-inch iPad (sim) | ✅ | Container added in `testAddContainersOnTheFloorAndInsideASpot` |

## Accessibility (screens touched: O-01, O-02, H-01–H-05, H-07)
- [x] Accessibility audit: `testRoomScreensPassTheAccessibilityAudit` runs `performAccessibilityAudit` on Welcome, Pick your rooms, Home with rooms, Room, Arrange Spots, Edit Room and Spot. It passes on the SE and the iPad. Two kinds of UIKit chrome are skipped, both commented in the test: the Dynamic Type check on a sheet's bar buttons, and element-less issues from the iPad floating bar's Rooms group.
- [x] VoiceOver labels: the Name and Spot name fields now have labels (they read only the placeholder before, D35). Breadcrumbs read "Garage, Metal shelf". Room cards read "Kitchen, Empty".
- [x] Move Up/Move Down actions on Arrange Rooms and Arrange Spots.
- [ ] **Owner:** light, dark and AX5 screenshots of Home, Room, Spot and the Room editor on the SE and the iPad. The Simulator panel wasn't available to the agent.

## No-AI check
n/a: the router isn't touched in P2.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | The iPad floating tab bar shows a **Rooms** group, from the sidebar's `TabSection`. Check it against the iPad boards; hide it there if the boards keep rooms in the sidebar only. |
| — | P3 | A delete can be undone but not redone (D35). |
| — | P3 | Narrowing with a room selected briefly shows the room tab in the tab bar for one frame before it hides (D35). |
