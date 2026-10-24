# Nook & Cranny v1.0 — App Store listing and release checklist (P13, D63)

This file holds what goes into App Store Connect by hand, plus the steps to ship. The owner enters everything. Nothing here is uploaded automatically.

## 1. Listing (en-US)
| Field | Limit | Draft |
|---|---|---|
| Name | 30 | Nook & Cranny: Home Inventory (29, D66) |
| Subtitle | 30 | Track belongings & warranties (29) |
| Promotional text | 170 | Photograph a room and Nook & Cranny lists what’s in it. Ask “Where are my passports?” and see the exact shelf. Private, on your device. Pay once, no subscription. (162) |
| Keywords | 100 | `insurance,receipt,scanner,tracker,moving,storage,household,property,organizer,declutter,valuables,qr` (100) |
| China mainland notes | — | Not applicable. The app contains no news, religious, book or magazine content. (An ICP filing number may also be needed for China mainland; if there isn't one, untick it under Pricing and Availability.) |
| Support URL | — | *Owner:* the hosted support page |
| Privacy Policy URL | — | *Owner:* the hosted privacy page (D58) |
| Category | — | Primary: Productivity · Secondary: Lifestyle |
| Price | — | Free download; Nook & Cranny Pro $14.99 once, Family Sharing on (D58) |

**Description**

> Know what you own, and exactly where it is.
>
> Nook & Cranny is a home inventory that remembers where everything lives: the passports in the desk drawer, the drill you lent to a neighbor, the winter coats in the blue bin. Photograph a room, and it helps you list what's on the shelf. Ask "Where are my passports?" and see the exact spot.
>
> FIND ANYTHING, FAST
> • Search as you type. It still finds things when you misspell them.
> • Ask "Where is the spare car key?" and see the room, the spot and when you last put it there.
> • Every item remembers where it has been, so you can see where the drill used to be.
> • Move something in two taps. Nothing ever moves without your tap.
> • Find or move things with Siri and Shortcuts, from Home Screen widgets, or from Control Center.
>
> BUILD YOUR INVENTORY WITHOUT THE TYPING
> • Photograph a shelf or a room, review what's there, and save it. Tap to name each item, or let Apple Intelligence suggest names on devices that support it.
> • Add one item in two taps with a photo and a name. Add up to 10 photos, plus brand, model, serial number, price, tags and notes.
> • Scan barcodes, serial numbers and model numbers.
> • Attach receipts as photos or PDFs.
>
> WARRANTIES AND RECEIPTS
> • Set the warranty length and get a reminder 30 days and 7 days before it ends. Reminders work offline.
> • See what's ending soon on Home and in a widget.
>
> MOVING OR STORING THINGS
> • Organize by room, spot and box.
> • Print or share a QR label for any box. Point the Camera at it to see what's inside.
>
> LENDING
> • Mark an item as lent, with who has it and when it's due.
> • See everything that's out in one filter.
>
> INSURANCE-READY REPORT
> • Make a PDF grouped by room, with photos, values, serial numbers, receipts and totals.
> • Export everything as CSV, or save a full backup file.
>
> PRIVATE BY DESIGN
> • No account, no tracking, no ads. Your things stay on your iPhone and iPad.
> • Lock the app with Face ID or Touch ID, and hide values with a tap.
> • Mark items Private to keep them out of Spotlight, Siri and widgets.
> • Apple Intelligence runs on your device. Every feature works without it.
>
> MADE TO FEEL AT HOME
> • VoiceOver, Larger Text, Dark Mode and six accent colors.
> • A sidebar, keyboard shortcuts and pointer support on iPad.
>
> FREE, THEN PAY ONCE
> Free includes unlimited rooms, search, backups and up to 25 items with 3 warranty reminders. Nook & Cranny Pro is a single purchase that unlocks unlimited items and reminders, insurance PDF and CSV export, and iCloud sync. It works with Family Sharing. No subscription.

The rules for this copy: no claim the app can't back up, AI never presented as required, and "subscription" never used except in "No subscription".

## 2. App Privacy: "Data Not Collected"
Answer **"No, we do not collect data from this app."** The reasons are in D63:
- Data stays on the device, or in the user's own CloudKit private database.
- There's no analytics, no account and no network code other than StoreKit and CloudKit (policy grep).
- The privacy manifests declare no collected data types and no tracking (`Nook/Resources/PrivacyInfo.xcprivacy`, `NookWidgets/PrivacyInfo.xcprivacy`).

## 3. Accessibility Nutrition Label
Each answer comes from the P13 audit (`docs/qa/p13-qa-report.md`). Claim a feature only when every common task supports it.

| Feature | Answer | Evidence |
|---|---|---|
| VoiceOver | Yes | Labels with name, room and value; custom actions; S13 with VoiceOver only |
| Voice Control | Yes | Visible names as input labels on cards; every control is labeled |
| Larger Text | Yes | Dynamic Type to AX5; grids become lists |
| Dark Interface | Yes | Every screen in dark mode |
| Differentiate Without Color Alone | Yes | Status is always an icon and text, never color alone (03 §11) |
| Sufficient Contrast | Yes | 4.5:1 tokens (`check_tokens.py`) and Increase Contrast variants |
| Reduced Motion | Yes | Every motion token has a Reduce Motion version (03 §9) |
| Captions | Not applicable | No video or audio content |
| Audio Descriptions | Not applicable | No video content |

If the owner's device pass (S13, Voice Control) finds a common task that doesn't work, change that row to "No" before submitting.

## 4. Age rating
None of the questionnaire's categories apply. The expected result is **4+**.

## 5. Screenshots
Produced by `ScreenshotTests` in App Store mode (seeded "showcase" home, Pro, light; the hero also in dark):

| Set | Simulator |
|---|---|
| iPhone 6.9" | iPhone 18 Pro Max |
| iPad 13" | iPad Pro 13-inch (M5) |

The order: Home (rooms), Room grid, Item detail, Find answer ("Where is the espresso machine?"), Classic scan tagging, Insurance report. Captions are added in App Store Connect, not baked into the images.

## 6. Release checklist
1. Gate 3 has passed (D60), and the P11 App Store Connect setup is done: product `pranav.nook.pro` (display name "Nook & Cranny Pro", D66), agreements, CloudKit schema deployed to Production, and Push (D59).
2. S-12's Contact Us writes to lightconeapps@gmail.com (`HelpScreen.contactAddress`). Use the same address on the support page.
3. Bump `CURRENT_PROJECT_VERSION` in `Nook.xcodeproj` for every upload. `MARKETING_VERSION` stays `1.0`.
4. Archive the Release build with the current release of Xcode (D23): Product → Archive, or
   `xcodebuild -project Nook.xcodeproj -scheme Nook -configuration Release -destination 'generic/platform=iOS' -archivePath build/Nook.xcarchive archive`
5. **Size:** export a local copy with the thinning report, which App Store exports don't make:
   `xcodebuild -exportArchive -archivePath build/Nook.xcarchive -exportPath build/size -exportOptionsPlist scripts/ExportOptions-size.plist`
   Check that every variant in `App Thinning Size Report.txt` is under 30 MB (PRD §9). After upload, App Store Connect's per-device sizes are the final word.
6. **Upload** through Organizer → Distribute App → App Store Connect. Organizer re-signs the build for distribution, so `aps-environment` becomes `production`. Confirm it on an App Store export with `codesign -d --entitlements :- <Nook.app>`.
7. **TestFlight:** at least 30 testers, with at least 10 on iPhones without Apple Intelligence and at least 5 on iPads (PRD §9). Include a 5-person first-run check against the under-3-minute target (D27). Watch crash-free sessions in Organizer until they're at least 99.8% (D63), and fix every crash before the RC.
8. Fill in §1–§5 in App Store Connect, and attach the screenshots.
9. Gate 4: every earlier gate's checks pass on the release candidate (roadmap). People decide the gate.
