# P7 QA report — 2026-10-09
Builds: `p7/warranties-lending` · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro Max, 13-inch iPad Pro (M5)

This is the full close the owner chose for Gate 2 (D50). Runs:
- **Build:** `build-for-testing` with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, 0 warnings.
- **Policy greps, tokens and color sets:** ✔ (`scripts/ci.sh`, 2026-10-09).
- **NookKit:** 91 ✔. New: `WarrantyAndLoanTests` (7) and `ReminderTests` (10):
  - warranty math: leap day, month end, days left;
  - the 30- and 7-day reminders at 9:00 and across daylight saving;
  - the 60-reminder cap, snooze, loans, Private copy;
  - reconciling touches only what changed;
  - delete and restore drop and bring back reminders.

  Search budget on an optimized build: slowest keystroke 9 ms at 5,000 items.
- **NookUI:** 21 ✔. **NookAI:** 19 ✔.
- **App tests:** see the matrix below.
- **Screenshots** (`docs/qa/p7/`): SE in light, dark and AX5, covering H-01, I-01 (Lent out and Warranty), I-02, I-06, R-01, R-04 (and empty), R-05 (and empty), and S-07 (and denied).

**Status:** In QA. The **Owner** rows need a real device: notifications, the contact picker and background refresh can't be fully exercised on the simulator.

Closing P7 turned up these problems, all fixed:
- **The Capture "3 items saved." toast vanished after a second** (`testClassicScanTagsThreeItemsAndSaves` failed on every device, and passes on `main`). P7 had tied Home's `NavigationStack` to the router, and that reset the tab's root, toast included. `TabRoot` is back to P6's version. A notification's View opens the item in a sheet, and See All pushes R-04 on Home's own stack (D50).
- **AX5:** a date with its Clear button was wider than an SE, which pushed I-06's content off the edge (I-02's Purchased row had the same risk); `ClearableDate` now stacks them. The system segmented control doesn't grow with text, so I-02's warranty length becomes a menu. Home's "Warranties ending soon" header now stacks above See All.
- **S-07's Time of day** stacks at accessibility sizes. Its note is a row, because a section footer didn't grow.
- **See All's hit area** was the text alone on iPad; it's now 44 pt.
- **Accessibility audit (D51):** the audit enlarges text without scrolling. Two kinds of findings are now skipped: List content pushed past the fold, and the text a system date picker draws. That clears P5's open Find finding.

## Acceptance (roadmap P7)
- [x] **Warranty end = purchase date + length (F4).** `endDateIsPurchasePlusLength` covers the leap day and month ends; `aLengthNeedsAPurchaseDate`; `testWarrantyFromTheEditorShowsOnItemAndInWarranties`.
- [x] **Reminders 30 and 7 days before,** at the S-07 time: `warrantyRemindsThirtyAndSevenDaysBeforeAtNine`.
- [x] **Rolling scheduler under iOS's 64 (D13):** `onlyTheSoonestSixtyArePending` and `reconcilingTouchesOnlyWhatChanged`. It reschedules on launch, after saves, on becoming active, after S-07 changes and in background refresh.
- [x] **Notification permission asked when the first reminder is saved (D15).** Saving a warranty with reminders, or a loan with Remind me, calls `askIfNeeded`. Denied: `testDeniedNotificationsShowTheWayToSettings`.
- [ ] **The reminder fires on schedule with no network (F4): Owner.** Set Time of day a minute ahead on an item whose warranty ends in 30 days, turn on Airplane Mode, and lock the phone.
- [x] **Warranties list (R-04):** groups, swipe Reminders Off with Undo, and the empty state's Add a Warranty.
- [x] **Lending (I-06)** with a contact or typed name, return date and reminder: `testLendShowsBadgeAndLentOutThenMarkReturnedUndoes`.
- [x] **Lent items show a badge and appear in Lent out (F7):** the same test, plus Find's Lent out filter (P5).

## Phase QA
| Case | Device | Result |
|---|---|---|
| Time zones and daylight saving | unit | ✅ Floating 9:00 triggers; `daylightSavingKeepsNineInTheMorning`. **Owner:** change the time zone, and the reminder still says 9:00 local |
| Leap days | unit | ✅ Feb 29 + 12 months = Feb 28; a 7-day reminder lands on Feb 29 |
| Warranty already expired | unit, SE | ✅ No reminders; R-04 Expired with no swipe; I-01 "Expired" |
| Notifications denied | SE | ✅ I-01, I-06 and S-07 show "Reminders are off for Nook." with Open Settings |
| Tapping a notification from a cold start | Owner | `AppDelegate` sets the delegate in `didFinishLaunching`; View opens the item in a sheet |
| Mark Returned / Snooze from a notification | Owner | Handled in the background through `AppDelegate`'s store |
| Contact picker | Owner | `CNContactPickerViewController`, no permission prompt |
| Background refresh | Owner | `BGAppRefreshTask` `pranav.nook.reminders` (D51) |
| Private item reminders | unit | ✅ Never named (`privateItemsAreNotNamed`) |

## Smoke suite
The full app suite ran on the SE and the 13-inch iPad, and the smoke classes on the 18 Pro Max (`ShellTests`, `RoomTests`, `ItemTests`, `MoveTests`, `FindTests`, `CaptureTests`, `WarrantyAndLendTests`). After the routing fix, `testClassicScanTagsThreeItemsAndSaves` and `WarrantyAndLendTests` were rerun on the SE (5 of 5 passed). Per the lean close, the iPad and Pro Max weren't rerun; CI on the PR covers them.

| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | SE, iPad, Pro Max | ✅ | `ShellTests`, including the iPad sidebar and ⌘1–⌘4 |
| S2 | SE, iPad, Pro Max | ✅ | `testCreateARoomWithThreeSpotsInUnder30Seconds` |
| S3 | SE, iPad, Pro Max | ✅ | `testAddInTwoTapsEditDeleteAndRestore` |
| S4 | SE, iPad, Pro Max | ✅ | `MoveTests` |
| S5 | SE, iPad, Pro Max | ✅ | `FindTests` (typo, answer card, last confirmed) |
| S6 | SE | ✅ | `testClassicScanTagsThreeItemsAndSaves` (after the fix), receipt tap-to-drop |
| S6 | iPad, Pro Max | ⏭ | Failed before the routing fix (the toast); not rerun (lean close). CI on the PR |
| S6 (F3 timing) | SE, iPad, Pro Max | ❌ known | `testEightItemsTaggedUnderTwoMinutes` also fails on `main` (P6) today, so it isn't caused by P7. Logged below |
| S7 | SE, iPad, Pro Max | ✅ | `WarrantyAndLendTests` (4): warranty → I-01 → R-04 and swipe; Lend → badge → R-05 → Mark Returned → Undo; Home row → See All; denied |

Accessibility audits on the SE and iPad: all pass except I-01's tags (below).

## Accessibility (screens touched)
- VoiceOver: R-04 and R-05 rows read name, date and status, with Reminders Off/On and Mark Returned as custom actions. Cards combine their text. Headers are marked.
- Dynamic Type to AX5: checked in screenshots (`docs/qa/p7/SE-ax5-*`).
- `AccessibilityAuditTests.testWarrantyAndLendingScreensPassTheAccessibilityAudit` covers Home's row, I-01's cards, I-06 (large detent), R-01, R-04, R-05 and S-07.
- **Open (P3, since P5, D47/D51):** I-01's tag chips report "Potentially inaccessible text" with no element; VoiceOver reads them.

## No-AI check
P7 doesn't touch the router; every P7 flow is Classic. No user-facing string mentions AI (catalog checked). **Owner, for Gate 2:** run US1–US6 and S3–S7 on a real iPhone without Apple Intelligence.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | I-01 tag chips: the audit reports element-less "Potentially inaccessible text" (P5 carry-over) |
| — | P2 | `testEightItemsTaggedUnderTwoMinutes` fails on `main` and on this branch on every simulator (F3's timing test). Not caused by P7; needs its own look |

## Gate 2 — Works with AI off (for the team's go/no-go)
- Stage 2 smoke S1–S7 on the SE simulator: see the matrix above.
- A real iPhone without Apple Intelligence: **Owner.**
- No screen shows an AI error or a dead end. Every P7 empty state has an action: Add a Warranty, Lend Something.
