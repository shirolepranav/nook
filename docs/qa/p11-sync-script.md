# P11 two-device sync script (S11, D58)

The roadmap's "two-device sync script". iCloud sync can't run in CI: it needs a signed-in Apple Account and the CloudKit container. Run it by hand on two devices, or on two simulators signed into the **same sandbox Apple Account**. Simulators don't get push notifications, so bring each app to the front to make it fetch.

## Once per schema change (owner)
1. Run a debug build on a device or simulator signed into iCloud, with the launch argument `-initializeCloudKitSchema YES`. The console prints "CloudKit schema initialized" (D59).
2. In the CloudKit Console, check that container `iCloud.pranav.nook` has its `CD_` record types in **Development**, plus `NookFile` (zone `NookFiles`), which appears after the first file syncs.
3. Before release, deploy the schema to **Production**.

## Setup
- Devices **A** and **B**, both signed into the same Apple Account, both running a debug build (`Nook.storekit` makes Pro free in Xcode), both with Pro.
- **B** starts with a fresh install and onboarding finished with the same preset rooms as A.

## Checks
| # | Steps | Expected |
|---|---|---|
| 1 | On A, Settings → iCloud Sync → turn on. | The screen goes back to iCloud Sync. Last synced fills in within a minute. Nothing is lost. |
| 2 | On B, turn on iCloud Sync. Wait, then bring it to the front. | A's items, rooms and spots appear. Each preset room shows **once** (dedupe by onboarding id). |
| 3 | On A, add "Kettle" with a photo and a receipt in Kitchen → Counter. | On B, Kettle appears, then its photo and receipt replace the placeholders. |
| 4 | On B, move Kettle to Pantry. | On A, Kettle is in Pantry, and its history shows both places. |
| 5 | Put A in airplane mode. On A, rename Kettle to "Kettle (old)". On B, change its notes. Then turn A's network back on. | Both edits land. For the same field, the later edit wins (last writer wins), and nothing duplicates. |
| 6 | On A, delete Kettle, then Recently Deleted → Delete Now. | Kettle leaves B's Home, then B's Recently Deleted, and its files are removed on B. |
| 7 | Restore the same `.nookbackup` with Merge on both A and B. | After syncing, every item shows once (`DedupeService`). |
| 8 | On B, sign out of iCloud in the Settings app, then open Nook → iCloud Sync. | The "You're signed out of iCloud" card shows, and every item is still on B. |
| 9 | Fill the account's iCloud storage (or use a nearly full test account), then add an item with photos. | The "Your iCloud storage is full" card shows. The item is saved on the device. |
| 10 | On A, turn iCloud Sync off, add "Lamp", then turn sync on again. | Lamp reaches B after sync is back on. Nothing is lost while it's off. |
| 11 | On A, refund Pro (Xcode's Transaction Manager), then relaunch. | Sync stops (Free), and every item, photo and move stays on A. S-03 shows the Pro card. |

Log the results in the P11 QA report under "Owner checks".
