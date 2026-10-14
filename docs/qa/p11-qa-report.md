# P11 QA report — 2026-10-14
Builds: `p11/pro-sync` · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen); 13-inch iPad Pro (M5) for the paywall form sheet

This was a minimal close, following the test cadence: no full `ci.sh`, and only the UI suites P11 touched. Runs:
- **Build:** zero warnings. **Policy greps and tokens:** ✔ (0 off-token colors, 0 off-grid spacing, 0 off-scale font sizes).
- **NookKit:** 124 ✔. New tests:
  - **`EntitlementLimitsTests`** (9):
    - the 26th item throws, Duplicate counts as an add, and a batch over the limit writes nothing
    - deleted items don't count, and restoring from Recently Deleted is never blocked
    - a refund keeps everything and only blocks new adds
    - the 4th active reminder throws; reminders that are off, ended or on deleted items don't count
    - editing an item whose reminder is already on isn't an add
  - **`SyncTests`** (6):
    - `DedupeService` merges a backup restored twice and keeps the later copy's unique history
    - onboarding rooms get the same id on every device and merge
    - FileSync record names round-trip and refuse thumbnails and garbage
    - BlobStore reports saves and removals, but not thumbnails or removals that came from iCloud
    - adopted files get a thumbnail
    - CloudKit errors map onto S-03's states
- **App unit tests (`NookTests`):** 11 ✔. **`StoreKitTests`** (6, `SKTestSession` with `Nook.storekit`):
  - one non-consumable at $14.99, Family Sharing on
  - buying unlocks and caches Pro
  - a refund takes Pro away
  - Ask to Buy waits, then unlocks on approval
  - a failed purchase stays Free
  - restore finds an earlier purchase
- **UI tests on the SE:**
  - `PaywallTests` 7/7 ✔ and `testP11ScreensPassTheAccessibilityAudit` ✔
  - the suites P11 touched all pass (52 tests): `ItemTests`, `CaptureTests`, `WarrantyAndLendTests`, `ReportsTests`, `OnboardingTests`, `AppearanceTests`, and the Settings and warranty audits. The 4 that first failed are fixed below.
- **13-inch iPad:** `testP11ScreensPassTheAccessibilityAudit` ✔ (P-01 as a centered form sheet), plus the never-on-launch, Export, sync-switch and Pro/restore paywall tests ✔, and `DeviceCopyTests` ✔.
- **Screenshots** (`docs/qa/p11/`), SE in dark mode: S-01 (Free and Pro), P-01 (offer and success), S-02, S-03 (Free and on) and S-09.

**Status:** In QA. Still to do: the **Owner** rows below, and smoke S1–S11 on CI.

Closing P11 turned up these problems, all fixed:
- **P11's Settings rows pushed the lower ones off the SE's screen.** Four earlier UI tests tapped "Appearance", "Notifications" or "Apple Intelligence" without scrolling. `XCUIApplication.settingsRow(_:)` now scrolls a row into view.
- **The unit-test host opened the real store with iCloud on.** Earlier UI tests had left the switch and the cached Pro flag on in the simulator's App Group. Under XCTest the app now never syncs. The accidental run also showed something useful: on a simulator with no iCloud account, the syncing store opens without a crash and reports 134400, which S-03 shows as signed out.
- **StoreKit refunds and Ask to Buy approvals arrive a moment later.** In the app, `Transaction.updates` refreshes the entitlement when they land. The tests now wait up to 5 s for the store to settle.
- **The string catalog's sync re-flowed empty entries** when a script rewrote the JSON. The iPad variations (D57) for S-03's and S-09's "this iPhone" are now inserted as text in Xcode's own format.

## Acceptance (roadmap P11)
- [x] **StoreKit 2 non-consumable with the native `ProductView`:** `NookProductViewStyle` draws the P-01 board's card and button. `proIsOneFamilySharedPrice`, `buyingUnlocksAndIsCachedForOfflineUse`.
- [x] **The entitlement from `Transaction.currentEntitlements`, cached offline:** `EntitlementCache` in the App Group, read at launch. `aRefundTakesProAway`, `restoreFindsAnEarlierPurchase`.
- [x] **The paywall at the 26th item, Export and the 4th reminder,** plus Back Up and S-03's switch (D9): `testTwentySixthItemOpensThePaywallAndSavesAfterTheUnlock`, `testExportOpensThePaywallAndAFailureStays`, `testFourthReminderOpensThePaywallAndAskToBuyWaits`, `testSyncSwitchOpensThePaywallWhenFree`.
- [x] **The paywall never appears on launch:** `testPaywallNeverAppearsOnLaunch` (with the Free tier full).
- [x] **Free users can always view, search and delete everything:** `testFreeCanStillFindAndDelete` and `deletedItemsDontCountAndRestoreIsNeverBlocked`.
- [x] **Restore Purchases:** `testProSeesTheThankYouAndRestores`, `restoreFindsAnEarlierPurchase`.
- [x] **Family Sharing:** on in `Nook.storekit`; S-02 shows "Shared with you through Family Sharing." for a family-shared transaction. **Owner:** turn it on for the product in App Store Connect.
- [x] **Pricing:** one price, $14.99, with no introductory offer (non-consumables can't have one; D58).
- [ ] **Two devices sync items, photos and moves: Owner.** It needs a signed-in account and the CloudKit container. The steps are in `docs/qa/p11-sync-script.md`. In the simulator, the switch reopens the store, and a store with no account shows S-03's signed-out state without crashing.

## Phase QA
| Case | Where | Result |
|---|---|---|
| Ask to Buy | unit, SE | ✅ `askToBuyWaitsThenUnlocksWhenApproved`; P-01 shows the waiting note with no button (`testFourthReminderOpensThePaywallAndAskToBuyWaits`); an approval while open turns into success (`onChange(of: isPro)`) |
| Interrupted purchases | unit, SE | ✅ a failed purchase stays Free and says so without blame; cancel stays quietly. **Owner:** kill the app mid-purchase on a device. `Transaction.updates` finishes it at the next launch |
| Purchasing offline | — | P-01 says "Nook Pro isn't available right now. Check your connection and try again." when the product can't load. A purchase made earlier works offline from `EntitlementCache`. **Owner:** airplane mode on a device |
| Signing out of iCloud mid-sync | simulator, no account | The store opens; setup reports 134400 → S-03's signed-out card. FileSync pauses on sign-out and turns sync off on an account switch. **Owner:** script check 8 |
| iCloud storage full | unit | ✅ `quotaExceeded` → the storage-full card (`cloudKitErrorsMapOntoS03`). **Owner:** script check 9 |
| Edits on two offline devices | — | **Owner:** script check 5 (last writer wins per field; both moves stay in history) |

## Owner checks
1. **App Store Connect:**
   - non-consumable `pranav.nook.pro`, $14.99, Family Sharing on
   - Paid Apps agreement and tax set up
   - a sandbox tester
2. **iCloud:**
   - container `iCloud.pranav.nook` and Push Notifications on the App ID
   - run `-initializeCloudKitSchema YES` once, then deploy the schema to Production before release (D59)
3. **Privacy URL:** host S-09's text and enter the URL in App Store Connect (D58).
4. **On a device:** a sandbox purchase, Ask to Buy, a purchase killed midway, and offline launch after buying.
5. **The two-device script** (`docs/qa/p11-sync-script.md`), checks 1–11.

## Smoke suite
| ID | iPhone SE | Note |
|---|---|---|
| S1–S10 | ⏭ | Minimal close: left to CI on the PR. The suites P11 touched were rerun on the SE (above) |
| S11 | ✅ / Owner (iPad: the paywall triggers ✅) | The 26th item opens the paywall, and the item saves after the unlock (`testTwentySixthItemOpensThePaywallAndSavesAfterTheUnlock`). Purchase and restore run in `StoreKitTests`. Device A → B is **Owner** (the script) |

## Accessibility
- The audit passes on S-01 (Free, with the Pro card), P-01 (offer and Ask to Buy), S-09, S-03 (Free and Pro on) and S-02, on the SE and the 13-inch iPad.
- P-01's card stacks at accessibility sizes. The success state is announced. Every link and button is 44 pt.
- New copy that names the device has an iPad variation (D57). Cross-device copy says "devices".

## No-AI pass
P11 adds no AI path. Every P11 UI test runs Classic (`-forceClassicEngine YES`).

## Performance
P11 touches no budgeted flow. `ItemService.checkCanAdd` is one `fetchCount`, and only for Free users.

## Open bugs
None found. Noted for later:
- **Orphaned files stay in iCloud.** Files from killed edits while sync is on are swept locally after 30 days but stay in iCloud (`ponytail:` in `RootView.tidyUp`).
- **The widget extension** reads the App Group store without CloudKit. P12 should confirm that's safe while the app mirrors it.
