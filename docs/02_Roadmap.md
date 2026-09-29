# Nook — Development Roadmap (phases, gates, QA)

- **Timeline:** about 14 weeks, from **Mon 2026-09-28**, launching in **early January 2027** (PRD §10).
- **Structure:** 4 milestones (M1–M4), each closed by a gate (G1–G4), split into **12 phases (P0–P11)** small enough for one PR series each (D18).
- **Links:** scope is in [00_PRD.md](00_PRD.md), screens in [01](01_Screens_and_Interactions.md), architecture in [04](04_Architecture.md), and test detail in [05](05_Testing_and_QA.md).

```
Wk  1   2   3 | 4   5   6   7 | 8   9   10 | 11  12  13 | 14
M1 Design     | M2 Core build | M3 AI + Duo | M4 Polish  | Review → launch
P0 ────────   | P2 ──         | P7 ─────    | P10 ────   |
P1   ──────── |   P3 ──────── |  P8 ─────   |   P11 ──── |
Figma ─────── |   P4 ──────── |   P9 ────── |            |
              |   P5 ──────   |             |            |
              |     P6 ────── |             |            |
            ◆G1             ◆G2          ◆G3          ◆G4
```

## How phases work (read this before starting any phase)

- **One phase = one epic.** Each phase has an owner (a phase lead), a GitHub milestone `P<N> – <name>`, and issues sized at ≤ 2 days.
- **Branches:** use `p<N>/<short-task>` (for example `p4/answer-card`), and open PRs into `main`. `main` must always build and pass tests.
- **Parallel lanes:** a phase lists its workstreams. Different people (or agents) can take different lanes at the same time. Lanes only touch the files and packages named for them, to avoid conflicts.
- **When a phase is Done:**
  - Its **Acceptance**, **QA** and **Regression** sections all pass.
  - The **cumulative smoke suite** (below) has been run and logged in the phase's closing PR.
  - The phase's Status line in this file is updated.
- **Gates:** a gate is a go/no-go review with the whole team at the end of a milestone. If it fails, the next milestone doesn't start. Fix it, then re-run the gate.
- **Definition of Done for every PR:** see [.github/pull_request_template.md](../.github/pull_request_template.md).
  - Code review by a teammate.
  - Unit tests plus a UI test for the primary flow.
  - Screenshots in light, dark and AX3 for UI changes.
  - No new Accessibility Inspector warnings.
  - The No-AI path is checked if the change touches the router.
  - Docs are updated if behavior changed.
- **Agents (Claude)** work the same way. Use the `phase-work` skill to pick up a phase, and never implement scope from a later phase.

### Team lanes (suggested roles)
| Lane | Owns |
|---|---|
| **Design** | Figma, prototype, copy, illustrations, icon |
| **UI** | NookUI package and app screens |
| **Platform** | NookKit (data, storage, sync), notifications, widgets, intents, StoreKit |
| **AI** | NookAI (router, both engines), evaluations |
| **QA** | Test plans, device matrix, smoke logs, accessibility audit |

One person can hold several lanes. The lanes exist to show what can happen in parallel.

---

## Cumulative smoke suite (run at the end of every phase; items join when their phase lands)

| ID | From | Check |
|---|---|---|
| S1 | P0 | Cold launch to the first screen with no crash, in light and dark, on SE and 18 Pro Max simulators |
| S2 | P1 | Every tab, the floating Capture button and the sidebar at regular width all render. Component gallery snapshots pass |
| S3 | P2 | Create a room with 3 spots and 1 container in under 30 s |
| S4 | P2 | Add an item with a photo and name in 2 taps. Edit it, delete it, then restore it from Recently Deleted |
| S5 | P3 | Manual room scan: draw 3 boxes, name them, Save all. They land in the right room/spot |
| S6 | P3 | Scan a receipt and tap-to-fill the price and date. Scan a barcode. Scan a serial |
| S7 | P4 | Find an item by name, by a typo, by a synonym, and by receipt text in under 100 ms (5k fixture). The answer card shows the breadcrumb and the last-confirmed date |
| S8 | P4 | Move an item in 2 taps. History shows the event. Undo works |
| S9 | P5 | Add a warranty and 2 pending reminders are scheduled. Lend an item: the badge shows and it appears in the Lent out filter |
| S10 | P6 | Room PDF opens in Files. CSV opens in Numbers. Backup → restore round-trips. A QR label opens its container |
| S11 | P7–P8 | AI room scan on an AI device. A forced fallback reaches the manual screen. A "Where is…?" question gets an answer. An AI move needs a confirm tap. `FindItemIntent` works from Shortcuts |
| S12 | P9 | Widgets render and deep-link. Duo fold/unfold keeps the room and scroll position. Split View works at compact width |
| S13 | P10 | App Lock works. A Private item is hidden from Spotlight and widgets. The paywall appears at the 26th item. Purchase and restore work in sandbox. Two-device iCloud sync works |
| S14 | P11 | Onboarding takes under 60 s. VoiceOver completes S4 and S8 end to end. At AX5, grids switch to lists |

Log the results in the phase's closing PR as a table (`S# · device · pass/fail · note`). The `qa-regression` skill produces this table.

---

# M1 — Design (weeks 1–3 · Sep 28 → Oct 18)

Design has 3 full weeks, per the PRD. Engineering builds the foundations and the design system in parallel, so M2 starts at full speed.

## P0 — Foundations
**Status:** Not started · **Weeks:** 1 · **Lanes:** Platform

- **Scope:**
  - The Xcode 27.1 project `Nook`, with iOS 27.0 deployment.
  - Targets: the app, `NookWidgets` (widget + controls extension), `NookTests`, `NookUITests`.
  - Local packages `NookKit`, `NookAI` and `NookUI`, empty with their test targets.
  - App Group `group.<bundle-prefix>.nook`.
  - Swift 6 language mode with strict concurrency.
  - SwiftFormat/SwiftLint config (build-tool only, not a runtime dependency).
  - CI (GitHub Actions on a macOS runner): build + unit tests + UI smoke on every PR.
  - An `OSLog` logger per package.
  - The launch screen.
  - A `FeatureFlags` enum for in-progress work.
  - The Build/Test commands filled in CLAUDE.md.
- **Deliverables:** an app shell that launches, green CI, and the project layout from 04 §3.
- **Acceptance:**
  - The build has zero warnings.
  - CI runs the unit and UI tests.
  - An internal TestFlight build uploads.
  - The app has no third-party runtime dependencies.
- **QA:** install on an iOS 27 device and simulator. Check the launch screen in light and dark.
- **Regression:** new: the build/launch check. Smoke: S1 (baseline).

## P1 — Design system & app shell
**Status:** Not started · **Weeks:** 1–3 · **Lanes:** UI (NookUI), Design (Figma, in parallel)

- **Scope:**
  - The **NookUI** tokens from [03](03_Design_System.md): color (including the 6 accents and 8 room colors), type, spacing, radii, elevation, motion, haptics.
  - Components: buttons, `NookCard`, `PhotoCard`, rows, chips, pills, text field, empty/loading/error states, toast, skeleton, warranty ring, location breadcrumb.
  - **App shell (D2):** 4 tabs, the floating Capture button, a sidebar at regular width, and placeholder screens.
  - An accent picker wired to `@AppStorage`.
  - A debug **Component Gallery** screen showing every component in every state.
- **Design lane, in parallel:** Figma frames for every screen in 01 at the PRD sizes (SE, 6.3", 6.9", Duo outer, Duo inner, Duo half-folded, AX5), plus a clickable prototype and illustrations for the empty states.
- **Deliverables:** the gallery, snapshot tests, and the prototype link added to the README.
- **Acceptance:**
  - All tokens resolve in light, dark and Increase Contrast.
  - Components reach AX5 without clipping.
  - The bars are native Liquid Glass and the content is opaque.
  - No hard-coded colors or sizes exist outside NookUI (checked by a lint rule or grep in CI).
  - The Capture placement is decided and logged (D2).
- **QA:**
  - Review against 03.
  - Check contrast with Accessibility Inspector.
  - Check both extremes of the Liquid Glass slider, and Reduce Transparency.
  - Test the shell at compact and regular width in the Duo simulator.
- **Regression:** new: snapshots × {light, dark} × {Large, AX3}. Smoke: S1–S2.

### ◆ Gate G1 — Prototype passes a 5-person test
- 5 people outside the team complete, on the prototype: "document a shelf", "find the passports", "move the drill", and "export a report".
- Each person finishes at least 3 of 4 tasks without help.
- Findings are triaged. P0/P1 design issues are fixed in Figma before M2.

---

# M2 — Core build, manual path everywhere (weeks 4–7 · Oct 19 → Nov 15)

M2 builds the **whole app without AI**. That's the classic engine, and it's what G2 checks. P2 comes first, then P3–P6 run in parallel.

## P2 — Data model & items CRUD
**Status:** Not started · **Weeks:** 4 · **Lanes:** Platform (models/repo), UI (screens)

- **Scope:**
  - The NookKit SwiftData models (Room, Spot, Item, Photo, Receipt, LocationEvent, Loan, Warranty; D21), following the **CloudKit-safe rules** (04 §4, D8).
  - `NookSchemaV1` with a `VersionedSchema` and a migration plan.
  - An App Group store.
  - Repository/services APIs.
  - Photo storage: HEIC on disk, 400-px thumbnails cached, 10 photos per item.
  - Screens: Home (3.1), Room Detail (3.2), Spot Detail (3.3), Item Detail (3.4, minus warranty and lending), Item Editor (3.5, manual), Room/Spot editor (3.8), Recently Deleted (3.10).
  - A debug seed generator (100 / 1,000 / 5,000 items).
- **Acceptance:**
  - F1: a room with 3 spots takes under 30 s.
  - F2: photo + name saves in 2 taps.
  - Delete, then restore within 30 days.
  - Inline validation.
  - The discard guard, and drafts when the app backgrounds.
  - A 1,000-item grid scrolls without dropped frames on a ProMotion device.
- **QA:** empty, max-length, emoji and RTL input. Locales. Kill the app mid-edit. 100 rooms. Duplicate room names.
- **Regression:** new: model and repository unit tests, migration test, CRUD UI tests. Smoke: S1–S4.

## P3 — Capture, manual path
**Status:** Not started · **Weeks:** 4–6 · **Lanes:** UI (capture screens), AI lane builds the **classic engine** in NookAI

- **Scope:**
  - The Capture menu (4.1).
  - The camera with coach hints.
  - **Room scan with manual tagging** (4.2): drawing boxes, and name suggestions from the 500-item list plus past items.
  - Add item (4.3), `PhotosPicker`.
  - Receipt scan with the document camera and **Vision OCR tap-to-fill** (4.4).
  - Serial scan by picking an OCR line (4.5).
  - The barcode scanner (4.6).
  - The camera permission soft-ask and denied states.
  - The capability router skeleton, returning `.classic` only for now (04 §5), so screens are already written against the router.
- **Acceptance:**
  - F3 manual: 8 items saved in under 2 min.
  - A failed receipt read still saves the image.
  - Each capture has a denied-camera route.
  - Barcode falls back to manual entry on unsupported devices.
- **QA:** crumpled or faded receipts, low light, several languages and currencies, huge PDFs, the camera denied mid-flow.
- **Regression:** new: OCR field-extraction tests on fixture receipts; the name-suggestion ranking test. Smoke: S1–S6.

## P4 — Find & Move (location memory)
**Status:** Not started · **Weeks:** 5–6 · **Lanes:** Platform (search index), UI (Find, answer card, move picker)

- **Scope:**
  - The Find tab (5.1): instant search, typo tolerance, a synonym list, filters, and saved searches.
  - Receipt OCR text is searchable.
  - The **answer card** (5.2) in its manual version.
  - The **Move picker** (3.6) with the last 5 used locations.
  - Multi-select move.
  - LocationEvent history.
  - "It's here ✓" (sets `lastConfirmedAt`).
  - Spotlight indexing for items, rooms and spots, excluding Private items.
- **Acceptance:**
  - F5: under 100 ms at 5,000 items.
  - F6: 2 taps to move.
  - Every answer shows the last-confirmed date.
  - A Spotlight result deep-links correctly.
- **QA:** diacritics, partial words, serial numbers, no results, 5k items, moving a container that has contents.
- **Regression:** new: search ranking tests, move/history tests, perf test (XCTest `measure`). Smoke: S1–S8.

## P5 — Warranties, lending & reminders
**Status:** Not started · **Weeks:** 5–7 · **Lanes:** Platform (scheduler), UI (screens)

- **Scope:**
  - The warranty section in the editor, the Warranties list (6.3), and detail/editor (6.4) with the proof pack as a stub until P6.
  - The Lend sheet (3.7), the Lent out list (6.5) and the badge.
  - The notification soft-ask.
  - The **rolling scheduler (D13)**: keeps the soonest 60 pending, and reschedules on launch, data change and background refresh.
  - Notification actions: View, Snooze, Mark returned.
  - The Home cards for "Warranties ending soon" and "Lent out".
- **Acceptance:**
  - F4: the end date is computed correctly, and reminders fire at 30 and 7 days **with no network**.
  - With more than 64 reminders, the next ones are still correct.
  - F7: the badge and filter work.
  - The denied-notifications state is shown inline.
- **QA:** time zone and DST changes, Feb 29, clock changes, a warranty already expired at creation, tapping a notification from a cold start.
- **Regression:** new: scheduler tests with an injected clock and a fake notification center; warranty date math tests. Smoke: S1–S9.

## P6 — Reports, exports & QR labels
**Status:** Not started · **Weeks:** 6–7 · **Lanes:** Platform (report service), UI (builder/preview)

- **Scope:**
  - The Reports tab (6.1) and the insurance report builder and preview (6.2), with a paged PDF via `ImageRenderer` that has the room grouping, photos, a receipts appendix and totals.
  - CSV export.
  - `.nookbackup` backup and restore (Replace/Merge) (D12).
  - The single-item proof pack.
  - **QR labels (3.9)** and the `nook://` deep links (D19).
  - Mixed-currency totals (D20).
  - Pro gating is **stubbed** (always unlocked, behind a flag) until P10.
- **Acceptance:**
  - F9: a 500-item PDF with photos in under 20 s, with no crash.
  - The CSV opens in Numbers and Excel.
  - Restore round-trips 100% of the fixtures.
  - F8: a QR code opens the right container from the system Camera.
- **QA:** a huge report, cancelling mid-generation, low memory, printing, restoring onto a fresh install.
- **Regression:** new: PDF page-count and CSV golden-file tests; backup round-trip test. Smoke: S1–S10.

### ◆ Gate G2 — The full app works with AI turned off
- On an iPhone **without** Apple Intelligence (or with it turned off), run all 6 user stories (US1–US6) end to end on SE and Pro Max.
- Every F1–F9 acceptance passes.
- No screen mentions AI or shows an error about it.
- This protects everyone on older iPhones. It is **not skippable**.

---

# M3 — AI and iPhone Duo (weeks 8–10 · Nov 16 → Dec 6)

## P7 — Capability router & AI capture
**Status:** Not started · **Weeks:** 8–9 · **Lanes:** AI

- **Scope:**
  - A full router (04 §5) that checks availability for each task.
  - **AI engine:**
    - Room scan with image input [Verify in SDK], using `@Generable DetectedItem` streaming.
    - The 1,536-px resize.
    - OCR and barcode tools offered to the model.
    - A 20 s timeout and silent fallback to manual tagging for that photo.
  - The detection cascade (an outline plus a haptic per item).
  - AI single-item fill, AI receipt extraction, AI serial finding, and the AI value estimate (always labeled).
  - The 100-photo Evaluations set and the harness [Verify in SDK].
  - A debug toggle to **force the classic engine** on AI devices.
- **Acceptance:**
  - F3 AI: at least 6 of 8 correct on the test shelf.
  - First card in under 2 s, and a full scan in under 8 s.
  - Every failure mode reaches the manual screen with the photo already loaded.
  - Both engines return the same result types.
- **QA:** a busy model, a guardrail refusal, airplane mode, low power, the model still downloading, Apple Intelligence turned off mid-session.
- **Regression:** new: router fallback unit tests (a mocked availability for every case), and an evaluation run logged in the PR. Smoke: S1–S11 (the AI rows as far as P7 has built them).

## P8 — AI "Where is…?", App Intents, Siri
**Status:** Not started · **Weeks:** 8–10 · **Lanes:** AI (question → query), Platform (intents)

- **Scope:**
  - The Foundation Models **tool-calling** layer. Question → structured query (item, room, time, action) → a database search → the answer phrased from records only.
  - Move statements produce the **move confirmation card** (5.3).
  - Spotlight semantic matching.
  - App Intents: `FindItemIntent`, `MoveItemIntent`, `ListRoomIntent`, `AddItemIntent`, `ScanRoomIntent`, with `AppEntity`s, App Shortcuts phrases, and view annotations.
  - Private items are never revealed through Siri.
  - The optional AI room summary in the PDF.
- **Acceptance:**
  - The AI never states a location that isn't in the database (an evaluation set of 30 questions, including trick questions about missing items).
  - Nothing moves without a tap.
  - Intents work from Shortcuts on non-AI devices.
- **QA:** ambiguous items, multiple matches, misspellings, questions about lent or packed items, Private items asked through Siri.
- **Regression:** new: App Intents tests, and the question→query evaluation. Smoke: S1–S11.

## P9 — Adaptive layouts, iPhone Duo, widgets & controls
**Status:** Not started · **Weeks:** 9–10 · **Lanes:** UI (layouts), Platform (widgets/controls)

- **Scope:**
  - Regular-width split views for every screen (01 §12).
  - Duo half-fold layouts with `ReservedRegion` [Verify in SDK].
  - The compact layout for the Duo outer screen.
  - Per-edge safe areas.
  - Context kept on fold and unfold (state restoration).
  - Split View at every width.
  - **Widgets:** Warranties ending soon, Total home value, and Quick find.
  - The Control Center control for room scan, the Lock Screen Move control, and the Action button option.
  - App-icon Quick Actions.
- **Acceptance:**
  - F10: widgets render correctly on every screen including Duo inner, in light, dark, tinted and clear.
  - Opening the Duo keeps the room and scroll position.
  - No `UIScreen.main` anywhere (enforced by a CI grep).
- **QA:** the Device Hub matrix (open, closed, rotated, folded, Split View on both sides), and an empty data set for widgets.
- **Regression:** new: widget snapshots, and UI tests on the Duo configurations. Smoke: S1–S12.

### ◆ Gate G3 — AI names 6 of 8 test-shelf items
- The standard test shelf (8 clear items, photographed per the protocol in 05 §4) gets at least 6 correct names on an Apple Intelligence iPhone, averaged over 3 runs.
- The 100-photo evaluation result is recorded as the baseline.
- G2 is re-run briefly (the No-AI pass) to confirm P7–P9 didn't break the manual path.

---

# M4 — Polish, monetization & beta (weeks 11–13 · Dec 7 → Dec 27; week 14 is the App Review buffer)

## P10 — Privacy lock, Pro & iCloud sync
**Status:** Not started · **Weeks:** 11–12 · **Lanes:** Platform

- **Scope:**
  - App Lock (1.2), Hide values, Private items (§9), and the app-switcher cover.
  - Data Protection `completeUntilFirstUserAuthentication`.
  - The privacy manifest and a "Data Not Collected" label.
  - **StoreKit 2:** a non-consumable Nook Pro product, `ProductView`, `Transaction.currentEntitlements` with an offline cache, the introductory offer, Family Sharing, and Restore.
  - The **Paywall** (§8) with the user's own numbers.
  - The Free limits (D9) enforced: replace the P6 stub.
  - **iCloud sync (Pro):** the CloudKit container, sync status UI, account changes, UUID dedupe, and the quota-full state.
- **Acceptance:**
  - Content is never visible before unlock.
  - Free users can always view, search and delete.
  - Purchase, restore and Ask to Buy work in sandbox and with the StoreKit config.
  - Two-device sync works, including photos.
  - Signing out and a full quota are handled.
- **QA:** biometrics not enrolled, lockout, backgrounding during the camera, interrupted purchases, offline purchase state, offline edits on both devices, signing out mid-sync.
- **Regression:** new: entitlement tests, lock state-machine tests, a sync dedupe test, and a two-device manual script. Smoke: S1–S13.

## P11 — Onboarding, polish, accessibility audit & beta
**Status:** Not started · **Weeks:** 11–13 · **Lanes:** everyone

- **Scope:**
  - Onboarding (§2) with the scan coach.
  - A motion and haptics pass: the zoom transitions, the "settle", and the detection cascade tuned on device.
  - Illustrations and copy.
  - The app icon (Icon Composer: light, dark, clear and tinted).
  - A **full accessibility audit** (05 §5) and the App Store Accessibility Nutrition Label.
  - Instruments passes against every PRD budget.
  - The download size under 30 MB.
  - **TestFlight with at least 30 external testers, 10 of them on non-AI iPhones.**
  - The App Store listing, screenshots, keywords, and the privacy page.
  - App Review prep.
- **Acceptance:**
  - Onboarding takes under 60 s and can be skipped.
  - Every PRD performance budget is met.
  - Every screen passes the accessibility checklist.
  - Zero open P0/P1 bugs.
  - The beta's crash-free rate is at least 99.8%.
- **QA:** exploratory sessions for each tab; the full device matrix (05 §3).
- **Regression:** new: a full regression of every phase suite. Smoke: S1–S14.

### ◆ Gate G4 — Launch (early Jan 2027)
- Crash-free sessions ≥ 99.8% over the last beta week.
- Zero P0/P1 bugs.
- G2 (No AI) and G3 (AI quality) re-pass on the release candidate.
- The App Store privacy label says "Data Not Collected".
- Submit in week 14 (Dec 28 → Jan 3), with release timed for the New Year organizing season.

---

## Traceability (PRD → phases)

| PRD ID | Phase(s) | PRD ID | Phase(s) |
|---|---|---|---|
| F1 Rooms, spots, containers | P2 | US1 Document a room by photo | P3 (manual), P7 (AI) |
| F2 Items | P2, P3 | US2 Fast manual add on older iPhones | P2, P3 |
| F3 Room scan | P3 (manual), P7 (AI) | US3 "Where is my…?" | P4 (manual), P8 (AI) |
| F4 Receipts & warranties | P3 (receipts), P5 | US4 Move in 2 taps | P4 |
| F5 Find | P4, P8 | US5 Export insurance PDF | P6, P10 (Pro gating) |
| F6 Move items | P4 | US6 Warranty reminder at 30 days | P5 |
| F7 Lending | P5 | §6 Location memory | P4, P8 |
| F8 Box labels | P6 | §7 Monetization | P10 |
| F9 Report & exports | P6 | §4 Device support / Duo | P1 (shell), P9 |
| F10 Widgets & controls | P9 | §9 Privacy & performance | P10, P11 (budgets watched every phase) |
| F11 Privacy lock | P10 | Onboarding (§3) | P11 |

## After launch (from PRD §10; not in scope now)
- **v1.1:** household sharing through iCloud shared zones, and localization (German, Spanish, French and Japanese first).
- **v1.2:** an iPad layout, which reuses the Duo inner-screen work.
- **v2:** Private Cloud Compute write-ups, an Apple Watch glance, and a Mac bulk editor.
