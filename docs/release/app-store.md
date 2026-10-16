# Nook v1.0 — App Store listing and release checklist (P13, D63)

This file holds what goes into App Store Connect by hand, plus the steps to ship. The owner enters everything. Nothing here is uploaded automatically.

## 1. Listing (en-US)
| Field | Limit | Draft |
|---|---|---|
| Name | 30 | Nook: Home Inventory *(placeholder: final name and trademark check open, PRD §10)* |
| Subtitle | 30 | Everything you own, and where |
| Promotional text | 170 | Photograph a room and Nook lists what’s in it. Find anything in seconds, track warranties, and make an insurance report. Private, on your iPhone. Pay once. |
| Keywords | 100 | `inventory,home,belongings,warranty,receipt,insurance,storage,moving,boxes,organizer,find,catalog` (99) |
| Support URL | — | *Owner:* the hosted support page |
| Privacy Policy URL | — | *Owner:* the hosted privacy page (D58) |
| Category | — | Primary: Productivity · Secondary: Lifestyle |
| Price | — | Free download; Nook Pro $14.99 once, Family Sharing on (D58) |

**Description**

> Nook knows everything you own and exactly where it is.
>
> Photograph a shelf and Nook lists the things on it. Or type a name and add a photo in two taps. Every item lives in a room, a spot and, if you like, a box, so "Where are the passports?" has an answer.
>
> • Find anything as you type, even with a typo
> • Move things in two taps, and see where they’ve been
> • Scan receipts and serial numbers, and get reminders before warranties end
> • Keep track of what you lent, and to whom
> • Print QR labels for boxes, then point the Camera at one to see what’s inside
> • Make an insurance report with photos, values and receipts
> • Lock Nook with Face ID, and keep Private items hidden from Spotlight, Siri and widgets
>
> Private by design. Your things stay on your iPhone and iPad. There’s no account, no tracking and no ads. Apple Intelligence helps where your device supports it, and every feature works without it.
>
> Nook is free for up to 25 items. Nook Pro unlocks unlimited items, reports, exports and iCloud sync with one purchase. No subscription.

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

The order: Home (rooms), Room grid, Item detail, Find answer ("Where are the passports?"), Classic scan tagging, Insurance report. Captions are added in App Store Connect, not baked into the images.

## 6. Release checklist
1. Gate 3 has passed (D60), and the P11 App Store Connect setup is done: product `pranav.nook.pro`, agreements, CloudKit schema deployed to Production, and Push (D59).
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
