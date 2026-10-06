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
| S1 | Resized iPad window | **Owner** | Selecting a room from the iPad sidebar works (checked by hand in the simulator), but simulated touch couldn't drag the window's resize grip. Narrow it with a pointer in Stage Manager: it should switch to the tab bar, keep the tab, and a selected room should fall back to Home (D35) |
| S2 | iPhone SE (sim) | ✅ | Room with 3 spots, under 30 s |
| S2 | iPhone 18 Pro Max (sim) | ✅ | |
| S2 | 13-inch iPad (sim) | ✅ | Container added in `testAddContainersOnTheFloorAndInsideASpot` |

## Accessibility (screens touched: O-01, O-02, H-01–H-05, H-07)
- [x] iPad floating tab bar: Home, Find, Reports and Settings only, matching the `iPadHome` 13p board. Rooms live in the sidebar. The TabSection is `.sidebarOnly` too (it had shown as a "Rooms" group), and `testArrangeRooms` asserts it. When a room is picked from the sidebar, iOS adds that room to the bar as the selected tab, which is expected.
- [x] Accessibility audit: `testRoomScreensPassTheAccessibilityAudit` runs `performAccessibilityAudit` on Welcome, Pick your rooms, Home with rooms, Room, Arrange Spots, Edit Room and Spot. It passes on the SE and the iPad. Two kinds of UIKit chrome are skipped, both commented in the test: the Dynamic Type check on a sheet's bar buttons, and element-less issues from the iPad floating bar's Rooms group.
- [x] VoiceOver labels: the Name and Spot name fields now have labels (they read only the placeholder before, D35). Breadcrumbs read "Garage, Metal shelf". Room cards read "Kitchen, Empty".
- [x] Move Up/Move Down actions on Arrange Rooms and Arrange Spots.
- [x] Screenshots in light, dark and AX5 (the largest accessibility size) on the SE and the iPad, captured by `ScreenshotTests` (opt-in, `TEST_RUNNER_RUN_SCREENSHOTS=1`) and reviewed one by one. Two AX5 bugs they caught are fixed: the Room editor's symbols overflowed and overlapped their tiles (now 3 columns at accessibility sizes), and Arrange rows broke names mid-word ("Counte / r"; the icon is dropped at accessibility sizes).

| Screen | iPhone SE | 13-inch iPad (portrait) |
|---|---|---|
| O-01 Welcome | [light](p2/SE-O-01-light.jpg) · [dark](p2/SE-O-01-dark.jpg) · [ax5](p2/SE-O-01-ax5.jpg) | [light](p2/iPad-O-01-light.jpg) · [dark](p2/iPad-O-01-dark.jpg) · [ax5](p2/iPad-O-01-ax5.jpg) |
| O-02 Pick your rooms | [light](p2/SE-O-02-light.jpg) · [dark](p2/SE-O-02-dark.jpg) · [ax5](p2/SE-O-02-ax5.jpg) | [light](p2/iPad-O-02-light.jpg) · [dark](p2/iPad-O-02-dark.jpg) · [ax5](p2/iPad-O-02-ax5.jpg) |
| H-01 Home | [light](p2/SE-H-01-light.jpg) · [dark](p2/SE-H-01-dark.jpg) · [ax5](p2/SE-H-01-ax5.jpg) | [light](p2/iPad-H-01-light.jpg) · [dark](p2/iPad-H-01-dark.jpg) · [ax5](p2/iPad-H-01-ax5.jpg) |
| H-02 Room | [light](p2/SE-H-02-light.jpg) · [dark](p2/SE-H-02-dark.jpg) · [ax5](p2/SE-H-02-ax5.jpg) | [light](p2/iPad-H-02-light.jpg) · [dark](p2/iPad-H-02-dark.jpg) · [ax5](p2/iPad-H-02-ax5.jpg) |
| H-03 Spot | [light](p2/SE-H-03-light.jpg) · [dark](p2/SE-H-03-dark.jpg) · [ax5](p2/SE-H-03-ax5.jpg) | [light](p2/iPad-H-03-light.jpg) · [dark](p2/iPad-H-03-dark.jpg) · [ax5](p2/iPad-H-03-ax5.jpg) |
| H-04 Room editor | [light](p2/SE-H-04-light.jpg) · [dark](p2/SE-H-04-dark.jpg) · [ax5](p2/SE-H-04-ax5.jpg) | [light](p2/iPad-H-04-light.jpg) · [dark](p2/iPad-H-04-dark.jpg) · [ax5](p2/iPad-H-04-ax5.jpg) |
| H-05 Container editor | [light](p2/SE-H-05-light.jpg) · [dark](p2/SE-H-05-dark.jpg) · [ax5](p2/SE-H-05-ax5.jpg) | [light](p2/iPad-H-05-light.jpg) · [dark](p2/iPad-H-05-dark.jpg) · [ax5](p2/iPad-H-05-ax5.jpg) |
| H-07 Arrange spots | [light](p2/SE-H-07-light.jpg) · [dark](p2/SE-H-07-dark.jpg) · [ax5](p2/SE-H-07-ax5.jpg) | [light](p2/iPad-H-07-light.jpg) · [dark](p2/iPad-H-07-dark.jpg) · [ax5](p2/iPad-H-07-ax5.jpg) |


## No-AI check
n/a: the router isn't touched in P2.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | At AX5 the Room editor's symbol tiles differ slightly in height (each follows its symbol's shape). |
| — | P3 | At AX5 the pinned "Continue with 4 rooms" button on O-02 takes about a third of the SE's screen; the list scrolls under it. |
| — | P3 | A delete can be undone but not redone (D35). |
| — | P3 | Narrowing with a room selected briefly shows the room tab in the tab bar for one frame before it hides (D35). |
