# P12 QA report — 2026-10-14
Builds: `p12/privacy-surfaces` · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen); 13-inch iPad Pro (M5)

Gate 3 was waived provisionally to start this phase (D60). The owner's choices are in D61 and the SDK findings in D62. The new boards (W01Widgets, CTL01Controls and the S-05 states) are on the Claude Design canvas (version 22) and in `design/screens/`.

Runs:
- **Build:** zero warnings with CI's `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`.
- **Policy greps and tokens:** ✔. The checker reports 0 off-token colors, 0 off-grid spacing values and 0 off-scale font sizes, including the new W01, CTL01 and S-05 boards.
- **NookKit:** 128 ✔. New tests:
  - `DeepLinkTests`: every link round-trips, and other links are refused.
  - `widgetSnapshotLeavesPrivateItemsOut`: no Private item counts toward the total or shows in the list, and the top rooms are ordered.
- **NookUI:** 24 ✔. New: `WidgetSnapshotTests` covers Warranties small, medium, large and empty, Total value small and medium, and Quick find, each in light, dark and Increase Contrast.
- **App unit tests (`NookTests`):**
  - `AppLockTests` (8):
    - a cold launch with the lock on starts locked
    - unlocking opens Private items too
    - the 1-minute and 5-minute timers at their boundaries
    - Private items close on background with the lock off, but not on inactive
    - a failed unlock stays locked
    - the switch asks first, and stays off without a passcode
    - the app-switcher cover rules
  - `IntentTests` (5):
    - Find answers from records, typos included
    - Private items are never entities and never in Spotlight
    - ListRoom counts Private items without naming them
    - Move writes one `.siri` event through `LocationService`
    - places cover rooms, spots and containers
- **UI tests, full suite on the SE:** 93 run, 16 skipped (opt-in screenshot and perf tests), 74 ✔ and 3 ✘, all accessibility audits:
  - **`testP12ScreensPassTheAccessibilityAudit`:** L-02 and the locked I-01 clipped text at enlarged sizes. Both now scroll, and on rerun it ✔.
  - **`testScreensPassTheAccessibilityAudit` and `testP11ScreensPassTheAccessibilityAudit`:** S-01's audit reports one "Dynamic Type partially unsupported" node, a different Settings text each run ("Recently Deleted", "Your data"), even with P12's new Face ID Lock row taken out. Not fixed in this PR (Open bugs).
  - After the run, xcodebuild hung once the tests had finished (the P11 trap), and was stopped.
- **UI tests, iPad:** `LockTests` and `testP12ScreensPassTheAccessibilityAudit` on the 13-inch iPad: 7/7 ✔, which covers L-02 and S-05 at regular width, and I-01's locked state beside the item column.

**Status:** In QA. Still to do: the **Owner** rows below.

## Acceptance (roadmap P12)
- [x] **The Face ID / Touch ID app lock (L-02, S-05) with an app-switcher cover:**
  - `testLockedLaunchStaysLockedWhenFaceIDFails`, `testLockedLaunchUnlocksWithFaceID` and `testTurningTheLockOnShowsLockAfter`
  - `AppLockTests`
  - The cover is its own window at alert level, so it covers sheets too (D61).
- [x] **Private items always need biometrics:** `testPrivateItemStaysHiddenWhenFaceIDFails`, `testPrivateItemOpensAfterFaceID`, and the audit's locked I-01 from a grid card.
- [x] **Private items are left out of Spotlight, Siri suggestions and widgets:** `privateItemsAreNeverEntities` (entities and the Spotlight set), `testFindItemIntentAnswersAndKeepsPrivateItemsOut` (out of process, through `AppIntentsTesting`), `widgetSnapshotLeavesPrivateItemsOut`.
- [x] **File protection `completeUntilFirstUserAuthentication`:** set explicitly on photos, receipts and restores; the store has the system default (D62). **Owner:** widgets after a restart, before the first unlock.
- [x] **Widgets (warranties, total value, quick find) reading the App Group store:** `WidgetSnapshot` through a read-only container, plus the snapshot tests. **Owner:** the system's tinted and clear styles.
- [x] **The Control Center control and the Action button option for room scan, and a Lock Screen control:** Scan Room and Find in Nook (D61). **Owner:** on a device.
- [x] **App Intents (`FindItemIntent`, `MoveItemIntent`, `ListRoomIntent`, `AddItemIntent`, `ScanRoomIntent`) as AppEntity types:** `IntentTests`, and `LockTests`' run through `AppIntentsTesting`.
- [x] **Spotlight indexing:** `IndexedEntity` through `SystemSurfaces`. **Owner:** search Spotlight on a device.
- [x] **The plain-language privacy page (S-09):** the Private items section, checked in the audit.
- [ ] **Widgets render correctly in every size on supported iPhones (F10):**
  - The content is snapshot tested at the SE's sizes, with every family laid out on the W01Widgets board.
  - **Owner:** add each widget on a device; the system draws the container.

## Phase QA
| Case | Where | Result |
|---|---|---|
| Biometrics not enrolled | unit, SE | ✅ With no passcode, S-05 shows "Set a passcode in Settings to lock Nook." with the switch off (`turningTheLockOnAsksFirst`). With a passcode and no biometrics, the copy says "Passcode". **Owner:** a device with Face ID not enrolled |
| Lockout | — | `.deviceOwnerAuthentication` falls back to the passcode, which the system handles. **Owner:** 5 failed Face IDs on a device |
| Widgets after a restart, before the first unlock | — | Can't run on the simulator, which doesn't enforce Data Protection. The provider shows "Unlock to see Nook." and retries in 15 minutes. **Owner** |
| Tinted and clear Home Screen styles | boards, snapshots | The boards show both styles, and accent parts are `widgetAccentable`. **Owner:** on a device |

## Owner checks
1. Add each widget, in every size, in default, tinted and clear styles. Mark an item Private and check it leaves the widgets. Turn on Hide values, and check Total value shows "••••" once Nook goes to the background.
2. Restart the phone and look at the widgets before unlocking.
3. Add Scan Room and Find in Nook in Control Center, on the Lock Screen and on the Action button. Each should open Nook to C-02 or Find.
4. Search Spotlight for an item (found; a tap opens it) and for a Private item (not found).
5. Ask Siri "Where is my drill in Nook" and "Move the drill in Nook", and confirm.
6. Face ID: turn the lock on, lock and unlock, fail 5 times, check the app switcher, and use Touch ID on an SE.

## Smoke suite
| ID | iPhone SE | Note |
|---|---|---|
| S1–S11 | ✅ | Every earlier phase's UI suite passes on the SE, apart from the two Settings audits above. Not run on the Pro Max; CI runs the iPad |
| S12 | ✅ | `testLockedLaunchUnlocksWithFaceID` (lock with Face ID), `privateItemsAreNeverEntities` and `widgetSnapshotLeavesPrivateItemsOut` (missing from Spotlight and widgets), `testFindItemIntentAnswersAndKeepsPrivateItemsOut` (FindItemIntent from Shortcuts) |

## Accessibility
- **The audit (`testP12ScreensPassTheAccessibilityAudit`)** covers L-02 failed, S-05, S-09, and a locked I-01 reached from a grid card.
- **L-02:**
  - The cover window is the only thing VoiceOver reads; Nook's window is under it.
  - The button reads "Unlock with Face ID".
  - With Reduce Motion, the failure pulse is skipped and the cross-fade stays, as a fade (03 §9).
- **S-05:** "Lock after" becomes a menu at accessibility sizes (D51).
- **Widgets:** each row reads as one element (name, then "Ends in 12 days"), and money reads in full ("12,480 US dollars").

## No-AI pass
P12 adds no AI path. Intents answer from records (`FindService`), and every P12 UI test runs Classic.

## Performance
- `SystemSurfaces` rebuilds the Spotlight entities 300 ms after a run of saves, on a background context (`ponytail:`, ~5k items). Flagged for P13's Instruments pass.
- Widgets read one `fetch` per timeline.

## Open bugs
- **P2 · The S-01 Settings audit is flaky** (`testScreensPassTheAccessibilityAudit`, `testP11ScreensPassTheAccessibilityAudit`). The audit reports one Settings text node as "partially unsupported" for Dynamic Type, a different one each run. It happens with P12's row removed too. Every row uses `.nookBody` and grows in the AX5 screenshots. Not checked on `main` from this branch: CI on the PR shows whether it predates P12.

Noted for later:
- **Home's summary rows** (warranty cards, R-04, R-05) keep "Private item" even after an unlock; only Find and the grids reveal names (D61).
