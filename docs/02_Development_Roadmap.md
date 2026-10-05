# Nook — Development Roadmap

**Source:** *Home Inventory & Warranty Vault — PRD + Technical Spec*. Screen IDs (H-01, C-03…) refer to `01_Pages_UI_Interactions.md`.

## How this roadmap is organized
- **Order, not dates.** Phases are listed in build order. There are no durations or deadlines; a phase is finished when its acceptance criteria, QA and regression all pass.
- **Two releases.**
  - **v1.0:** phases P0–P13, for iPhone and iPad (D29). Built with the current release of Xcode; no beta needed.
  - **v1.1 (iPhone Duo support):** phase P14. Needs the iOS 27.1 SDK in Xcode 27.1.
  - **v1.2 (iPad drag and drop, multiple windows):** phase P15 (D29).
- **Stages and gates:** the PRD describes 4 stages with a gate at the end of each. Each gate must pass before the next stage starts. Gate 2, "works with AI off", protects everyone on older iPhones (PRD §10). The PRD's embedded roadmap diagram wasn't readable in the attached file, so the stages are reconstructed from the PRD text.
- **Stack (PRD §8):** Swift 6, SwiftUI, Observation; iOS 27.0 minimum; SwiftData in an App Group; Foundation Models; Vision and VisionKit; Core Spotlight; CloudKit private database (Pro); StoreKit 2; WidgetKit; App Intents. No third-party dependencies.
- **Packages (PRD §8):** NookKit (models and storage), NookAI (router and both engines), NookUI (design system).

> **Correction to PRD §8:** the PRD says to build with the iOS 27.1 SDK. Only the iPhone Duo work needs it. Foundation Models image input is part of the iOS 27 SDK, so v1.0 builds with the released Xcode 27. Build the v1.0 release with whichever Xcode is the current release when you submit. Settled by D23 (accepted 2026-10-04); PRD §8 now matches.

| Stage | Phases | Gate |
|---|---|---|
| 1. Design | P0, P0b | Gate 1: Design sign-off (P0b: iPad boards signed off by the product owner) |
| 2. Core app, Classic path | P1–P7 | Gate 2: Works with AI off |
| 3. AI, exports, Pro | P8–P11 | Gate 3: Feature complete |
| 4. Platform, polish, release | P12–P13 | Gate 4: v1.0 ready to submit |
| v1.1 | P14 | Gate 5: Duo support ready to submit |
| v1.2 | P15 | Gate 6: iPad extras ready to submit |

## Testing rules for every phase
- **QA:** manual and exploratory testing of the phase's new screens on this matrix:
  - iPhone SE simulator (smallest screen)
  - iPhone 18 Pro and Pro Max simulators, including Pro Max in landscape for regular-width layouts
  - 13-inch iPad simulator in portrait, landscape and a narrow resized window, plus iPad mini (D29)
  - SwiftUI previews at custom sizes for wide layouts
  - one real Apple Intelligence iPhone and one real older iPhone (PRD §9)
  - light and dark mode, the largest accessibility text size, and VoiceOver on every new screen
- **Regression:** two parts.
  1. **New-feature regression:** automated tests for everything added in this phase.
  2. **Smoke check of earlier phases:** run the cumulative smoke suite below. Each phase adds its own line, so the suite grows as the app does.
- **Definition of Done:** code reviewed; unit tests and a UI test for each primary flow; light, dark and largest-text screenshots attached to the pull request; no new Accessibility Inspector warnings; smoke results logged.

## Cumulative smoke suite
Run on the iPhone SE, iPhone 18 Pro Max and 13-inch iPad simulators at minimum. A phase runs every line up to and including its own.

| ID | Added in | Check |
|---|---|---|
| S1 | P1 | Cold launch to Home in light and dark mode, no crash, tab bar and Capture button visible; Pro Max landscape and the 13-inch iPad show the sidebar; resizing the iPad window to narrow switches to the tab bar without losing the current tab; ⌘1–⌘4 switch tabs |
| S2 | P2 | Create a room with 3 spots and a container in under 30 s |
| S3 | P3 | Add an item with photo and name in 2 taps; edit it; delete it; restore from Recently Deleted |
| S4 | P4 | Move an item in 2 taps; the move appears in its location history |
| S5 | P5 | Find an item by name with a typo in under 100 ms; answer card shows location and last confirmed date |
| S6 | P6 | Classic room scan: tag 3 items on a photo and save; receipt tap-to-drop fills price and date |
| S7 | P7 | Add a warranty and see reminders scheduled at 30 and 7 days; lend an item and see it under Lent out |
| S8 | P8 | AI room scan saves items; with Apple Intelligence off, the same photo opens manual tagging |
| S9 | P9 | Ask "Where are the passports?" and get the right answer; "I put X in Y" moves only after the tap |
| S10 | P10 | Generate a 500-item insurance PDF; a QR label opens the right container from the Camera app |
| S11 | P11 | 26th item opens the paywall; sandbox purchase and restore work; an item added on device A appears on device B |
| S12 | P12 | Lock the app with Face ID; a Private item is missing from Spotlight and widgets; FindItemIntent works from Shortcuts |
| S13 | P13 | Complete S3 and S5 end-to-end with VoiceOver only |
| S14 | P14 (v1.1) | On the iPhone Duo simulator: opening and closing keeps the room and scroll position; half-folded capture uses top and bottom halves |
| S15 | P15 (v1.2) | On iPad: drag an item onto another room and Undo it; open a second window and lock the app, and both windows are covered |

---

## Stage 1 — Design

### P0 · Design foundations & prototype
**Status:** Done (2026-10-04, PRs #1–#12). Gate 1 signed off by the product owner on 2026-10-04.
**Goal:** settle the look, feel and flows before code, because design is the main way Nook wins (PRD §3).
**Scope**
- Design system tokens (see `03_Design_System.md`): warm neutrals, 6 accents, room palette, type, 8-pt spacing, concentric corners, motion and haptics.
- Frames on the Claude Design canvas (re-synced into `design/`) for every v1.0 screen in `01_Pages_UI_Interactions.md` at 4.7" SE, 6.3", 6.9", 6.9" landscape (regular width), and the largest accessibility text size. Duo frames wait for v1.1.
- Clickable prototype of the top 6 user stories (PRD §2), built from the linked HTML mockups, including the AI and Classic versions of room scan.
- Empty, loading and error illustrations (PRD §3).
- App icon in Icon Composer: light, dark, clear and tinted (PRD §3).
- Decide the Capture button placement (floating action vs tab).

**Deliverables:** Claude Design canvas and `design/screens/`, prototype link, `design/icon/`, written decisions log.
**Acceptance:** every screen has all states designed; every flow has a Classic path; text contrast passes 4.5:1.
**QA:** 5 hallway tests of the prototype, including one person using VoiceOver if possible. Target: a new user "documents" a room in the prototype in under 3 minutes. *Replaced for P0 by an expert review and link check; real-user sessions move to the first builds and TestFlight (D27).*
**Regression:** no code yet. Instead, run a design consistency review: every frame uses tokens only, with no one-off colors or sizes.

**Gate 1 — Design sign-off:** prototype tested, open design questions closed, assets exported.

### P0b · iPad design (D29)
**Status:** Not started. Runs alongside P1. It must be signed off before P2, because P2 builds the first real screens.
**Goal:** make the existing designs look right on iPad before screens are built, so iPad costs a few checks per screen instead of a later rework.
**Scope**
- iPad boards on the Claude Design canvas (re-synced into `design/`) at 13-inch landscape and portrait, and iPad mini portrait, for every screen that changes at wide widths: Home, Room, Spot, Item detail, Find, Scan review, Reports, Settings.
- One form-sheet board for editors and pickers, plus the paywall as a form sheet and the Capture menu as a popover.
- One resized-window board showing the switch from regular to compact.
- Pointer hover states for photo cards and rows; the keyboard shortcut list (01 §1.5).
- Teach `design/tools/check_tokens.py` the wide-window tokens in `03` §4 (`cardMinWidth`, `maxGridColumns`, `readableWidth`).

**Acceptance:** every iPad board uses tokens only (`check_tokens.py` passes); nothing stretches past `readableWidth` or 6 grid columns; every board has light and dark.
**QA:** expert review of the iPad boards against `03` §12 and an accessibility review (D27 format).
**Regression:** the token checker over all of `design/screens/`.

---

## Stage 2 — Core app on the Classic path
Everything in this stage works with no AI, so Gate 2 can prove the app is complete on older iPhones.

### P1 · Project setup & app shell
**Status:** Not started
**Scope:** Xcode project with a universal app target (iPhone and iPad, D29), widget extension and the three local packages; one window on iPad and the menu-bar shortcuts verified in the SDK (D29); CI running unit and UI tests on iPhone and iPad simulators; NookUI with tokens and core components (buttons, photo card, room card, chips, fields, empty state, toast, skeleton); tab shell (Home, Find, Reports, Settings) with the floating Capture button; adaptive shell (tab bar on compact width, sidebar on regular width); appearance settings with the 6-accent picker (S-06); launch screen (L-01).
**Acceptance:** builds with no warnings; cold launch to Home under 400 ms on iPhone 15 (PRD §9); no hard-coded colors or sizes outside NookUI; tab bar becomes a sidebar on Pro Max landscape and iPad; ⌘1–⌘4 switch tabs.
**QA:** components gallery checked in light, dark, Increase Contrast, Reduce Transparency, and the strongest and weakest Liquid Glass settings.
**Regression:** new — snapshot tests for each component in light and dark, default and largest text. Smoke — S1.

### P2 · Rooms, spots & containers
**Status:** Not started
**Scope:** NookKit SwiftData models from PRD §8 (Room, Spot, Item, Photo, Receipt, LocationEvent, Loan) created **sync-ready from the start** (every property optional or defaulted, relationships optional with inverses, no unique constraints), so CloudKit in P11 needs no migration; Home with room cards (H-01); Room (H-02), Spot and container (H-03), editors (H-04, H-05), arrange rooms (H-07); onboarding (O-01, O-02).
**PRD acceptance:** create a room with 3 spots in under 30 seconds (F1).
**QA:** nesting limit (containers one level deep), deleting rooms with content, 50+ rooms, long names, VoiceOver room reordering.
**Regression:** new — model unit tests (nesting, ordering, deletes); onboarding and room UI tests. Smoke — S1–S2.

### P3 · Items, photos & Recently Deleted
**Status:** Not started
**Scope:** item editor (I-02) with every F2 field and the 500 common items autocomplete; item detail (I-01) with zoom transition; photo viewer (I-03); photos stored as HEIC on disk with cached 400-px thumbnails (PRD §8); receipts as image or PDF (I-07); Private flag stored (lock behavior comes in P12); Hide values; Recently Deleted for 30 days (S-08); multi-select (I-08).
**PRD acceptance:** a photo-and-name item saves in 2 taps (F2); a 1,000-item grid scrolls at 120 fps on ProMotion with no dropped frames (PRD §9).
**QA:** 10 photos per item, huge PDFs, camera denied, low storage, emoji and right-to-left names, killing the app mid-edit.
**Regression:** new — item CRUD unit tests, thumbnail cache tests, editor UI tests, grid scrolling performance test. Smoke — S1–S3.

### P4 · Move & location history
**Status:** Not started
**Scope:** Move picker (I-04) with the last 5 locations; multi-item move; LocationEvent recording with source; location history (I-05); last confirmed date; "Found it here instead".
**PRD acceptance:** moving one item takes 2 taps (F6).
**QA:** moving containers with items inside, moving into a container, undo after move, history after deleting a spot.
**Regression:** new — LocationEvent unit tests (from, to, source); move UI tests. Smoke — S1–S4.

### P5 · Find, Classic search
**Status:** Not started
**Scope:** Find tab (F-01) using the system search role; instant results (F-02) with typo tolerance and the synonym list ("fob" → "key"); answer cards (F-03) for location, lent, packed, room contents and quantity; filters (F-05) including last seen date; saved searches (F-06); receipt text included in search.
**PRD acceptance:** results under 100 ms for 5,000 items (F5).
**QA:** misspellings, partial words, serial numbers, accents and diacritics, no results, Private items appearing as hidden.
**Regression:** new — search ranking unit tests (PRD §9); performance test with 5,000 seeded items. Smoke — S1–S5.

### P6 · Classic capture
**Status:** Not started
**Scope:** Capture menu (C-01); room scan camera (C-02) with coach overlay; manual tagging (C-04) with tap or draw boxes and name suggestions; quick add (C-05); receipt scan (C-06) with Vision text recognition and tap-to-drop; barcode scanner (C-07); serial sticker reader (C-08) listing recognized lines; just-in-time camera permission; receipt import from Files and the share sheet.
**PRD acceptance:** manual path saves 8 items in under 2 minutes (F3).
**QA:** low light, blurry photos, crumpled and faded receipts, several currencies and date formats, camera denied, interruptions (a phone call during capture).
**Regression:** new — receipt number and date detection tests on a fixture set; manual tagging UI test. Smoke — S1–S6.

### P7 · Warranties, reminders & lending
**Status:** Not started
**Scope:** warranty end date computed from purchase date plus length (F4); reminders 30 and 7 days before; a rolling scheduler that keeps the soonest reminders within iOS's 64 pending notification limit and reschedules on launch and after changes; notification permission asked when the first reminder is set; Warranties list (R-04); lending (I-06) with contact picker, return date and reminder; Lent out list (R-05).
**PRD acceptance:** the reminder fires on schedule on a device with no network (F4); lent items show a badge and appear in the Lent out filter (F7).
**QA:** time zones and daylight saving changes, leap days, warranty already expired, notifications denied, tapping a notification from a cold start.
**Regression:** new — date math and scheduler unit tests with a fake clock (PRD §9); loan UI tests. Smoke — S1–S7.

**Gate 2 — Works with AI off:** the full Stage 2 app passes all smoke checks on the iPhone SE simulator and a real iPhone without Apple Intelligence. No screen shows an AI error or a dead end.

---

## Stage 3 — AI, exports & Pro

### P8 · Capability router & AI room scan
**Status:** Not started
**Scope**
- NookAI router (`currentEngine()` checks `SystemLanguageModel.default.availability`, PRD §8).
- **Vision check (added):** before choosing the AI path for photos, also confirm the on-device model supports image input. Developer reports suggest some Apple Intelligence models lack it; those iPhones use the Classic photo path while keeping AI for text questions.
- AI room scan pipeline: resize to 1,536 px, structured `DetectedItem` output, OCR and barcode tools offered to the model, streaming results, fallback to manual tagging on busy, guardrail or 20 s timeout (PRD §8).
- Scan review (C-03) with sequential outlines and light haptics; AI prefill on quick add; Apple Intelligence settings status (S-11).

**PRD acceptance:** 8 clear items give at least 6 correct suggestions (F3); first card in under 2 s; full one-photo scan under 8 s (PRD §9).
**QA:** model downloading, Apple Intelligence turned off mid-session, a model without image input, cluttered shelves, mirrors and screens in photos, the same item in two photos.
**Regression:** new — router fallback unit tests including the vision check (PRD §9); AI quality tests with Apple's Evaluations framework on 100 labeled household photos (PRD §9). Smoke — S1–S8.

### P9 · AI receipts, serials, values & "Where is…?"
**Status:** Not started
**Scope:** AI receipt extraction (store, date, price, warranty length); AI serial labeling; replacement value range labeled as an estimate; natural-language questions turned into structured searches with tool calling (PRD §6); move-by-sentence with the confirmation card (F-04); Spotlight semantic matching ("car fob" → "Spare car key").
**Acceptance:** answers come only from saved data; nothing moves without the confirmation tap (PRD §6); every AI field is editable and marked as suggested.
**QA:** ambiguous questions ("Where's the key?" with 4 keys), items with the same name in two rooms, misheard voice input, very long receipts.
**Regression:** new — question-to-search parsing tests; evaluation set for answers; confirmation-required UI test. Smoke — S1–S9.

### P10 · Reports, exports, backup & QR labels
**Status:** Not started
**Scope:** insurance report builder and preview (R-02) rendered with SwiftUI `ImageRenderer` (PRD §8), grouped by room with photos, values, serials, receipt appendix and totals, optional AI room summaries; watermarked free preview; CSV export (R-03); .nookbackup create and restore (S-04); QR box labels (H-06) and deep links from the system Camera app (F8).
**PRD acceptance:** a 500-item PDF generates on-device in under 20 seconds (F9); QR opens the correct container from the Camera app (F8).
**QA:** cancelling mid-report, low memory, printing, restoring onto a device with existing data, CSV opening in Numbers and Excel.
**Regression:** new — PDF and CSV golden-file comparisons; backup round-trip test (export, wipe, restore, compare). Smoke — S1–S10.

### P11 · Nook Pro & iCloud sync
**Status:** Not started
**Scope:** StoreKit 2 non-consumable with the native `ProductView`; entitlement checked with `Transaction.currentEntitlements` and cached offline (PRD §7); paywall (P-01) at the 26th item, Export and the 4th reminder; Restore Purchases; Family Sharing; introductory pricing; iCloud sync with the CloudKit private database for Pro users (S-03).
**Acceptance:** the paywall never appears on launch; free users can always view, search and delete everything; two devices sync items, photos and moves.
**QA:** Ask to Buy, interrupted purchases, purchasing offline, signing out of iCloud mid-sync, iCloud storage full, edits on two offline devices.
**Regression:** new — entitlement logic tests with StoreKit configuration files; paywall trigger UI tests; two-device sync script. Smoke — S1–S11.

**Gate 3 — Feature complete:** every PRD feature (F1–F11) is in; the "no AI" pass is repeated with Apple Intelligence off (PRD §9).

---

## Stage 4 — Platform, polish & v1.0 release

### P12 · Privacy lock, Private items & system surfaces
**Status:** Not started
**Scope:** Face ID / Touch ID app lock (L-02, S-05) with an app-switcher cover; Private items always need biometrics and are excluded from Spotlight, Siri suggestions and widgets (PRD §9); file protection `completeUntilFirstUserAuthentication` (PRD §9); widgets (warranties, total value, quick find) reading the App Group store; Control Center control and Action button option for room scan; Lock Screen control; App Intents (`FindItemIntent`, `MoveItemIntent`, `ListRoomIntent`, `AddItemIntent`, `ScanRoomIntent`) as AppEntity types; Spotlight indexing; plain-language privacy page (S-09).
**PRD acceptance:** widgets render correctly in every size on supported iPhones (F10; Duo inner screen checked in v1.1).
**QA:** biometrics not enrolled, lockout, widgets after a restart before first unlock, tinted and clear Home Screen styles.
**Regression:** new — App Intents Testing framework (PRD §9); widget snapshots; Private-exclusion tests. Smoke — S1–S12.

### P13 · Polish, accessibility, performance & v1.0 release
**Status:** Not started
**Scope:** motion and haptics polish; full accessibility audit (VoiceOver, Voice Control, largest text, Reduce Motion, Reduce Transparency, Increase Contrast, every Liquid Glass setting) and an honest App Store Accessibility Nutrition Label (PRD §3); regular-width layout review on Pro Max landscape and every iPad size, since Duo owners will also see these layouts on the inner screen; pointer and keyboard pass on iPad (D29); Instruments passes against every PRD §9 budget; download size under 30 MB; "Data Not Collected" privacy label; TestFlight beta with at least 30 testers, 10 of them on iPhones without Apple Intelligence and at least 5 on iPads (PRD §9); App Store keywords and screenshots, including the 13-inch iPad set; final app name check (PRD §10 open questions).
**Acceptance:** zero known crash or data-loss bugs; crash-free sessions at 99.8% or higher in beta (PRD §1); all PRD §9 performance budgets met.
**QA:** exploratory sessions per tab; one full "no AI" release pass (PRD §9).
**Regression:** new — full run of every phase's automated suite. Smoke — S1–S13.

**Gate 4 — v1.0 ready to submit:** all earlier gates' checks pass on the release candidate build, built with the current release of Xcode.

---

## v1.1 — iPhone Duo support

### P14 · iPhone Duo layouts
**Status:** Not started
**Prerequisite:** Xcode 27.1 (released version), which includes the iOS 27.1 SDK and the iPhone Duo simulator.
**What changes for Duo owners:** v1.0 (built with the iOS 27 SDK) uses most of the inner screen but leaves space at the edges. Rebuilding with the iOS 27.1 SDK lets the app reach the edges; this phase adds the Duo-specific poses on top.
**Scope:** rebuild with the iOS 27.1 SDK; items tagged **[v1.1 Duo]** in `01_Pages_UI_Interactions.md`: half-folded layouts for capture and item detail with `ReservedRegion` around the hinge, keeping context when opening or closing, the Duo outer-screen Home with the Quick find bar, vertical bars on the outer screen; asymmetric safe areas; Split View at every width; removing any `UIScreen.main` use (PRD §4, §8); Duo design frames (outer, inner open, half-folded).
**Acceptance:** content reaches the inner screen's edges; nothing sits on the hinge; widgets render correctly on the Duo inner screen (F10).
**QA:** the full Duo simulator matrix: open, closed, rotated, tent and book poses, Split View on both sides (PRD §4).
**Regression:** new — UI tests for the top 6 user stories on iPhone SE, iPhone 18 Pro Max and iPhone Duo open, closed and half-folded (PRD §9). Smoke — S1–S14, plus a full "no AI" pass because the whole app is rebuilt with a new SDK.

**Gate 5 — v1.1 ready to submit:** P14 acceptance met and every smoke check passes on both the Duo and standard iPhones.

---

## v1.2 — iPad extras (D29)

### P15 · iPad drag and drop & multiple windows
**Status:** Not started
**Scope:** items tagged **[v1.2 iPad]** in `01_Pages_UI_Interactions.md`:
- **Drag and drop:** items onto rooms, spots and containers, always through `LocationService.move` with Undo, a VoiceOver equivalent, and a "Move" accessibility action. Photos and receipts can be dropped in from Files and other apps.
- **Multiple windows:** each window remembers its own tab, room and scroll position. Locking the app or Hide values covers every window at once. Private items stay hidden in every window until unlocked.
- **Widgets:** the extra-large family on iPad.

**Acceptance:** a drop never moves anything without Undo; two windows editing the same item never lose a change; locking covers every window.
**QA:** dragging between windows, dropping onto a container in a collapsed sidebar, locking with two windows open, a drop while a sheet is open.
**Regression:** new — drag-and-drop UI tests; a two-window lock test. Smoke — S1–S15.

**Gate 6 — v1.2 ready to submit:** P15 acceptance met and every smoke check passes on iPhone and iPad.

---

## PRD performance budgets to track (PRD §9)
| Moment | Budget | Checked from |
|---|---|---|
| Cold launch to Home | Under 400 ms on iPhone 15 | P1 |
| Scrolling a 1,000-item grid | 120 fps on ProMotion, no dropped frames | P3 |
| Search results as you type | Under 100 ms for 5,000 items | P5 |
| First AI item card after a photo | Under 2 s | P8 |
| Full room scan (one photo, ~10 items) | Under 8 s on an AI iPhone | P8 |
| 500-item insurance PDF | Under 20 s | P10 |
| App download size | Under 30 MB | P13 |

## Risks (from PRD §10)
| Risk | Where it lands | Mitigation in this plan |
|---|---|---|
| AI misnames or misses items | P8–P9 | Classic path finished first (Gate 2); evaluation set runs every phase after P8 |
| Some AI iPhones can't read images | P8 | Vision check in the router; those iPhones use the Classic photo path |
| Users stop updating locations | P4, P12 | Move from answer cards, search, widgets, Siri and Lock Screen |
| Duo owners see v1.0 before Duo polish | P13, P14 | Size-class layouts reviewed in P13; P14 follows in v1.1 |
| iPad support can't be removed once shipped | P0b, P13 | iPad boards before P2; iPad in every phase's QA and the smoke suite (D29) |
| Apple changes Foundation Models behavior | P8 onward | Router fallback; rerun evaluations on each iOS update |
| Scope needs trimming | Any | Move AI room summaries in the report, saved searches and Declutter to a later version, since none are in the top 6 user stories |

## Open questions from the PRD (§10)
- Final app name ("Nook" is a placeholder).
- Oldest iPhone that supports iOS 27, to fix the smallest test device.
- Launch countries and currencies for value fields.
