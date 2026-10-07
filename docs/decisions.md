# Decisions Log

Resolutions for anything the PRD leaves open, or where earlier drafts conflicted with it. **Precedence: [00_PRD.md](00_PRD.md) > this file > every other doc.** If you change a decision, add a new entry that supersedes the old one. Don't edit history.

Format: `ID · Date · Status` — Decision. *Why.* *Affects:* docs/code.

Status values: **Accepted**, **Proposed** (a PR is open and needs a lead's approval), **Superseded by Dxx**.

---

### Merge of earlier drafts (2026-09-28)
Earlier drafts of the screens, roadmap and design system were written without access to the PRD. They were called "Home Inventory & Warranty Vault" and assumed iOS 26, 5 tabs, no AI and an iPad target. We kept their craft (tokens, states, platform constraints, QA structure) and made the scope match the PRD. The entries below record every conflict.

**D1 · 2026-09-28 · Superseded by D23 (build SDK only)** — The minimum OS is **iOS 27.0**, built with the **iOS 27.1 SDK / Xcode 27.1**. *Why:* the PRD needs Foundation Models image input and full-screen iPhone Duo support. *Affects:* project settings, and all availability checks (no `#available(iOS 26…)` branches).

**D2 · 2026-09-28 · Accepted** — **Navigation:**
- Tabs are **Home · Find · Reports · Settings**.
- Find uses `Tab(role: .search)`.
- **Capture is not a tab.** It is a floating Liquid Glass button (`.buttonStyle(.glassProminent)`) that opens the Capture menu: Scan room, Add item, Scan receipt, Scan barcode.
- At regular width the tab bar becomes a sidebar.

*Why:* the PRD says the capture button floats, and a tab is a destination, not an action. *Open:* the exact placement mechanism (overlay versus `tabViewBottomAccessory`) is chosen in P1 after prototype testing, and the result is logged here. *Affects:* 01, 03, the P1 shell.

**D3 · 2026-09-28 · Accepted** — The **location hierarchy is Room → Spot → Container.** A container is a Spot with a parent Spot, and it nests at most one level deep. The drafts' "Places / Location" concept is dropped. *Why:* PRD F1 and the data model. *Affects:* NookKit models and all pickers.

**D4 · 2026-09-28 · Accepted** — **Warranties do not get a tab.** The warranty list lives in Reports, and a "Warranties ending soon" card sits on Home. A **claim helper is out of scope**, because filing claims directly is a PRD non-goal. We keep an "Export proof pack" (the item PDF with its receipts) inside Warranty Detail, because it is simply F9 scoped to one item. *Affects:* 01, P5.

**D5 · 2026-09-28 · Accepted** — **Color:**
- The drafts' "Warm Linen" neutrals are kept.
- The accent can be picked from **6 options**. **Terracotta** is the default; the others are Sage, Ocean, Plum, Slate and Rose. Honey is left out because it is the "ending soon" status color.
- Each room gets a soft **room color** from an 8-swatch palette, plus an SF Symbol.

*Why:* the PRD visual system. *Affects:* 03 §2, NookUI.

**D6 · 2026-09-28 · Accepted** — **Spacing uses an 8-pt grid.** A 4-pt half-step is allowed only for tight internal padding (chips, pills, icon gaps). *Why:* the PRD specifies an 8-pt grid, and the drafts used 4-pt steps. *Affects:* the `NookSpace` tokens.

**D7 · 2026-09-28 · Accepted** — Items have **up to 10 photos** each, stored as HEIC on disk with cached 400-px thumbnails. *Why:* PRD F2 and the stack table. The drafts allowed 20.

**D8 · 2026-09-28 · Accepted** — **iCloud sync is Pro only.** The SwiftData model is **CloudKit-safe from P2 onward**: every attribute is optional or has a default, every relationship is optional with an inverse, there are no unique constraints, and no Deny delete rules. Sync ships in P10. Onboarding has **no** sync step. *Why:* PRD §7. Building the model this way now avoids a migration later.

**D9 · 2026-09-28 · Accepted** — **Monetization:**
- The Free tier allows 25 items and 3 active warranty reminders.
- **Nook Pro** is a one-time non-consumable purchase for $19.99, with a $14.99 introductory price for the first 2 weeks, and Family Sharing on.
- The paywall appears only at a moment of value: adding a 26th item or tapping Export (the PRD's two triggers), plus the two limits that follow from the tier table, saving a 4th active reminder and turning on iCloud sync. It never appears on launch and never blocks view, search or delete.

*Affects:* entitlement gating in P10.

**D10 · 2026-09-28 · Accepted** — **The PRD's performance budgets win:**
- Cold launch under 400 ms (iPhone 15)
- Search under 100 ms at 5,000 items
- 1,000-item grid at 120 fps
- First AI card under 2 s
- Room scan under 8 s
- 500-item PDF under 20 s
- Download under 30 MB
- Crash-free sessions ≥ 99.8%

The drafts' looser budgets (1.5 s launch, 150 ms search) are dropped.

**D11 · 2026-09-28 · Accepted** — **APIs that need verification.** Anything marked `[Verify in SDK]` in the docs comes from beta notes, developer reports or the PRD, and nobody has checked it against the shipping SDK. Before relying on one, confirm it in Xcode 27.1 and record the result here. Current list:
- `ReservedRegion` (27.1)
- Foundation Models image input
- `toolbarMinimizationBehavior(_:for:)` (possibly renamed from `toolbarMinimizeBehavior`)
- `.reorderable()`
- `Tab(role: .prominent)`
- Swipe actions on arbitrary scroll-container views
- Item-binding alerts and confirmation dialogs
- The Evaluations framework API
- iPhone Duo point sizes

**D12 · 2026-09-28 · Accepted** — The backup file extension is **`.nookbackup`**, a zip of JSON and photos with a `manifest.json` that carries a `schemaVersion`. The drafts' `.vaultbackup` is dropped.

**D13 · 2026-09-28 · Accepted** — **Notifications use a rolling scheduler.** iOS keeps at most **64 pending local notification requests** per app. The scheduler keeps the soonest 60 pending, which leaves headroom for loan reminders. It reschedules on launch, on data changes and on background refresh. *Why:* at scale, warranty reminders (30 and 7 days before each end date) plus loan reminders exceed 64. *Affects:* P5.

**D14 · 2026-09-28 · Accepted** — **Recently Deleted** keeps deletes for 30 days, and an Undo toast appears for 5 s after every delete. This comes from the drafts and matches PRD pillar 4.

**D15 · 2026-09-28 · Accepted** — **Permission prompts are just-in-time** (from the drafts). Camera is requested on the first Scan tap, notifications when the first warranty or loan reminder is saved, Contacts when "Choose contact" is tapped in lending, and Face ID when App Lock is enabled. The photo library needs no prompt, because we use `PhotosPicker`. *Affects:* 01 §10.

**D16 · 2026-09-28 · Accepted** — **Items.** The drafts' "estimated value" field is replaced by the PRD's AI value range, clearly labeled as an estimate and shown on AI iPhones only. The drafts' "Mark as Sold/Disposed", "maintenance reminders", multi-home and CSV import are **out of v1**. *Why:* they aren't in the PRD. Propose them for v1.x through a PR to 00_PRD.md.

**D17 · 2026-09-28 · Accepted** — The PRD text says "six everyday jobs" but its table lists eight. We treat this as a typo and use eight (`J1`–`J8`).

**D18 · 2026-09-28 · Accepted** — **The team works in phases.** Phases P0–P11 sit inside the PRD's 4 milestones and 4 gates (see [02_Roadmap.md](02_Roadmap.md)). Each phase ends with its own QA, plus the cumulative smoke suite from the drafts.

**D19 · 2026-09-28 · Accepted** — **Deep links and QR codes use the custom scheme `nook://`.** There are no universal links, because they need a web server and "no server" is a PRD non-goal. QR labels encode `nook://spot/<qrId>`. [Verify in SDK] that the system Camera opens custom-scheme QR codes. If it doesn't, the fallback is scanning labels from inside Nook: Capture → Scan barcode also reads QR codes.

**D20 · 2026-09-28 · Accepted** — **Mixed currencies.** Each item stores its own currency. Totals are shown in the home currency (Settings). If any item uses a different currency, the total shows "Mixed currencies" and a per-currency breakdown. We never convert, because live rates would need the network.

**D21 · 2026-09-28 · Accepted** — **Warranty is its own entity.** In the PRD model the warranty is a single `warranty end` field on Item. The screens, though, need a type (manufacturer / extended / store), a provider, a policy number, a cost, reminder offsets, and sometimes more than one warranty per item (a manufacturer warranty plus an extended one). The design:
- Add a `Warranty` model: item, type, provider, startDate, endDate, lengthMonths, policyNumber, cost, reminderOffsetsDays (default `[30, 7]`), notes.
- `Item.warrantyEnd` becomes a derived value: the latest `endDate`.
- Reminders are **not stored**. The scheduler derives them from Warranty and Loan dates.

*Affects:* 04 §4, P2, P5.

### P0 alignment (2026-10-03)

**D22 · 2026-10-03 · Accepted** — **Errata for older entries.** The roadmap grew to P0–P14 and was renamed after D1–D21 were written. We don't edit history, so read the older entries this way:
- D4 "P5" → P5 (Find) and P7 (warranties). D8 "P10" → P11. D9 "P10" → P11. D13 "P5" → P7. D21 "P2, P5" → P2, P7.
- D18 "P0–P11 … 4 gates" → P0–P14 with 5 gates (Gate 5 is v1.1). Its link `02_Roadmap.md` is now `02_Development_Roadmap.md`.
- D2 "chosen in P1": P0 chooses the **visual placement** of the Capture button through prototype testing (roadmap P0 scope). P1 verifies the SwiftUI mechanism in the SDK and logs it.
- D5: `03` §2.2 still listed Honey and Graphite. It now lists D5's Slate and Rose, with values that pass 4.5:1 for white-on-accent and accent-on-surface (light) and for `onAccent` on the dark accents.
- Design work happens on the Claude Design canvas, re-synced into `design/`, not in Figma. The P0 prototype is the linked HTML mockups.
- The Xcode project and CI are created in P1 (roadmap), not P0 (CLAUDE.md and `05` said P0).

*Affects:* CLAUDE.md, PRD §4 and §10 (design-tool wording only), 02, 03, 04, 05, the PR template, the `phase-work` and `data-model-change` skills.

**D23 · 2026-10-03 · Accepted (2026-10-04, product owner)** — **SDK for v1.0.** The minimum OS stays **iOS 27.0**. v1.0 builds with the **current release of Xcode 27**. The **iOS 27.1 SDK / Xcode 27.1** is needed only for v1.1 (P14, iPhone Duo). Supersedes D1's build-SDK clause. PRD §8 is updated to match. *Why:* Foundation Models image input is in the iOS 27 SDK. Only `ReservedRegion` and the full-screen Duo layout need 27.1. D1, the PRD and the roadmap's "Correction to PRD §8" currently disagree. *Affects:* PRD §8, 04 header, CLAUDE.md "Unverified APIs", CI Xcode version.

**D24 · 2026-10-03 · Accepted** — **Token contrast fixes (P0).** `design/tools/check_tokens.py` now checks every allowed text/background pair in `03` §2. To make them all pass:
- Light accents get slightly darker so they work as text on every surface: Terracotta `#B4502C` → `#AC4C2A`, Sage `#4F7A57` → `#4A7251`.
- Light semantic colors get darker: `success` `#3D7A4C` → `#3A7549`, `warning` `#A4610E` → `#985A0D`.
- `textTertiary` is for disabled and decorative use only. Placeholders use `textSecondary`.
- Every text, accent, semantic and border token gets a High Contrast variant (7:1 for text and accents, 3:1 for borders). Room colors need none.
- A new token, `hairlineStrong`, covers dashed "add" cards.
- Named motion and haptic tokens are added (03 §9, §10).

*Why:* the starting values failed 4.5:1 in places (Terracotta on text-field wells was 4.19:1), and `03` §2.5 required High Contrast variants that didn't exist. *Affects:* 03 §2, §8.6, §9, §10; the mockups (fixed in the P0 screen batches); NookUI color sets in P1.

**D25 · 2026-10-04 · Accepted** — **Illustrations are layered vectors, tinted at runtime.** Each illustration ships as three SVGs in `design/illustrations/`:
- `<name>-light.svg` and `<name>-dark.svg`: the base layer, in the warm palette and room colors
- `<name>-accent.svg`: a one-color template layer that the app tints with the user's accent

The source is `design/tools/illustrations.py`; run it to re-export. In P1 they become asset-catalog images: the base is an image set with Any and Dark appearances, and the accent is a template image drawn over it with `.foregroundStyle(.tint)`. Accent shapes never carry details in another color, because those would sit under the accent layer and vanish.

*Why:* `03` §7 asks for the accent as the highlight color, and there are 6 accents. Drawing 6 × 2 versions of each illustration would be 96 files to keep in sync. *Affects:* 03 §7, NookUI (P1), the empty and error states.

**D26 · 2026-10-04 · Accepted** — **Capture is a floating button (placement A).** It's a 56 pt Liquid Glass button at the bottom trailing corner, above the tab bar, with a soft accent glow on Home until the first item is saved. Placement B, an accessory bar above the tabs, is dropped. Resolves D2's open question. *Why:* chosen by the product owner after comparing both on the canvas. A takes almost no content space, while B covered about 60 pt on iPhone SE. A matches PRD §3 ("floating Liquid Glass button"). Apple meant the bottom accessory for ongoing content like Now Playing, not for an action. *Affects:* 01 §1.2, 03 §8.1, the P1 shell (P1 still verifies the SwiftUI mechanism, D2).

**D27 · 2026-10-04 · Accepted** — **P0 user testing is an expert review; real users test in TestFlight.** There's no time for the 5 hallway sessions the roadmap asks for in P0. P0 QA is instead:
- an automated link and reachability check of the prototype
- a cognitive walkthrough of every user story, with tap counts and time estimates
- an accessibility review of the boards

Real-user testing moves to the existing P13 TestFlight beta (30 testers, 10 without Apple Intelligence), plus a 5-person first-run check as soon as the P2–P3 builds can document a room. The hallway script in `design/research/p0-review.md` is reused for that. *Why:* the product owner has no time for sessions now, and a design-phase expert review catches most layout and copy problems. *Risk accepted:* nobody has watched a first-time user or a VoiceOver user yet. Both are tracked as open risks for Gate 2. *Affects:* roadmap P0 QA and Gate 1.

**D28 · 2026-10-04 · Accepted** — **The `[Inferred]` items from 01 §16 are closed** as designed on the canvas:
- Capture is a floating action, not a tab (D26).
- There's an app-level "Use Apple Intelligence" toggle, shown only when Ready or Downloading (S-11).
- **Lock timing:** Right away (default), 1 min or 5 min.
- **Hide values** is off by default.
- **Saved searches:** swipe to Rename or Delete.
- **Share-sheet import** uses an "Open in Nook" document type for images and PDFs, so no Share Extension is needed for v1.
- **Deleting a room that has items** asks "Move Items to Another Room" or "Move Items to Recently Deleted".
- **Free limit during a room scan:** cards beyond 25 items stay in review until the user unlocks Pro or removes some (01 §15). The paywall opens on Save.
- **Find on regular width:** results sit beside the answer card.
- **Widgets** honor Hide values.
- **Snooze** is 1 week for warranties and 1 day for loans.
- **The notification permission** is asked when the first reminder is saved (D15).
- **The report cover** shows the home name, insurer, policy number and date.

New since `01` was written: the room editor lists the room's spots with "Add spot" (F1's 30-second target), and scan review has "Accept All" (F3's 2-minute target). *Affects:* 01, the canvas.

**D29 · 2026-10-05 · Accepted (2026-10-05, product owner)** — **iPad ships in v1.0, with layout parity plus pointer and keyboard support.** This moves iPad up from v1.2 (PRD §10). Nook becomes a universal app: iOS 27.0 and iPadOS 27.0 minimum, with one adaptive layout and no device or idiom branching.
- **In v1.0:**
  - Every screen looks right and works on iPad in portrait, landscape and any resized window (Split View, Stage Manager, windowed apps), using the regular-width layout that's already designed (PRD §4 rule 2).
  - Wide-window rules (03 §5): photo grids grow to at most 6 columns, and text-heavy content is capped at a readable width.
  - On regular width, editors, pickers and the paywall open as centered form sheets, and the Capture menu (C-01) opens as a popover from the Capture button.
  - **Pointer:** a hover effect on every tappable card and row, and long-press menus also open with a secondary click.
  - **Keyboard shortcuts** for the main commands (01 §1.5). They also appear in the iPad menu bar.
- **In v1.2:**
  - drag and drop (items onto rooms and spots, photos and receipts from Files)
  - multiple windows
  - extra-large widgets
- **v1.0 shows one window at a time.** P1 confirms in the SDK that multiple scenes can be turned off for a SwiftUI app on iPadOS 27 [Verify in SDK]. If not, P1 logs a new decision.
- **Room scan on iPad** keeps the same flow. Quick add and receipt scan stay one tap away in the Capture menu, because holding up a big tablet to scan a room is awkward.
- **Apple Intelligence** works on iPads that support it, through the same router check (PRD §8). Every other iPad uses the Classic path.

*Why:* the layouts already follow size classes, and regular-width layouts exist for Pro Max landscape and the Duo inner screen. That makes iPad cheap now and expensive to add after the screens are built. An iPhone-only Nook would run on iPad in a small, phone-sized window, and App Review tests it there anyway. Pointer support and shortcuts are close to free in SwiftUI and make the app feel native with a keyboard. Drag and drop has to go through `LocationService.move`, with Undo and VoiceOver equivalents. Multiple windows would have to keep the Face ID lock, Hide values and Private items correct in every window. Both deserve their own phase. *Cost accepted:*
- every PR's QA adds iPad checks
- iPad support can't be removed once it ships
- App Store iPad screenshots are needed

*Affects:* PRD §1, §4, §5, §8, §9, §10; 01 header, §1.1, §1.3, §1.5, §14, §15; 03 §5; 04 §9; 05 §3; roadmap (P0b, P1, P13, the smoke suite, v1.2); CLAUDE.md; the canvas (iPad boards).

**D30 · 2026-10-05 · Accepted** — **D29's two `[Verify in SDK]` checks, tested in Xcode 27.0 (27A266a) on the iOS 27.0 simulator (13-inch iPad Pro M5).** Both used a throwaway SwiftUI app. Shortcuts were pressed through XCUITest `typeKey`, with the window focused and up to 3 tries per key.
- **One window is possible, but it's not the default.**
  - The SwiftUI app template generates `UIApplicationSupportsMultipleScenes = YES`. Nook's starter project in `nook/` has the same setting (`INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES`).
  - With the default, `openWindow` and `activateSceneSession` each opened another window.
  - With `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO` and an Info.plist whose `UIApplicationSceneManifest` sets `UIApplicationSupportsMultipleScenes` to `NO`:
    - `supportsMultipleScenes` is `false`
    - `openWindow(id:)` does nothing
    - `activateSceneSession` fails with "The application does not support multiple scenes."
    - the app stays at one window, which was also checked on screen
  - **P1 must set this**, and a test checks `supportsMultipleScenes == false` until P15.
- **Keyboard shortcuts in a `CommandMenu` reach the iPad menu system**, between View and Window. The system adds the app menu, File (Close, ⌘W), Edit (Undo and Redo on ⌘Z and ⇧⌘Z, plus Cut, Copy and Paste), View, Window and Help.
  - **Works:** ⌘N, ⇧⌘N, ⌘E, ⇧⌘M and ⌥⌘M.
  - **⌘M doesn't work.** iPadOS keeps it: in one run it minimized the app's window, and in the others it did nothing. **Move becomes ⇧⌘M** (01 §1.5).
  - **⌘⌫ never fired from XCUITest**, with either delete character (U+007F or U+0008). Apple's own iPad apps use ⌘⌫, so this may be a limit of simulated input. **P1 checks it with a hardware keyboard.** If it fails there too, Delete keeps only its menu item and the swipe or context-menu action.
- **The system "Settings…" item (⌘,) opens the iPad Settings app**, leaving Nook. `CommandGroup(replacing: .appSettings)` takes over ⌘, (checked: it fires the app's own command). **Nook uses it to open its Settings tab** (01 §1.5).
- **Not checked:** the menu bar opened on screen. A simulated swipe from the top edge didn't keep it open, so the menu contents were read from the menu system instead. P1 takes a screenshot with a hardware keyboard and pointer, and also checks ⌘1–⌘4.

*Affects:* 01 §1.5 (Move is ⇧⌘M, ⌘, opens Settings), 04 §9 (the `[Verify in SDK]` tags are resolved), the roadmap P1 scope, the `iPadMenu` board, Nook's Xcode project settings.

### P1 (2026-10-05)

**D31 · 2026-10-05 · Accepted (2026-10-05, product owner)** — **Project setup.**
- **Project:** the Xcode starter in `nook/` moved to the root as `Nook.xcodeproj`, with the targets `Nook`, `NookTests`, `NookUITests` and `NookWidgets`. It uses synchronized folders (`objectVersion 110`), so new files join their target without project-file edits. Swift 6 language mode, iOS and iPadOS 27.0, universal.
- **Identifiers:** these follow the owner's other app. App `pranav.nook`, widgets `pranav.nook.NookWidgets`, App Group `group.pranav.nook` (`NookKit.appGroupID`), team `6WSVMM9FGS`. The iCloud container `iCloud.pranav.nook` is reserved for P11 and isn't added until then.
- **One window (D30):** `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO` and `Nook/Info.plist` sets `UIApplicationSupportsMultipleScenes` to `NO`. `NookTests/SceneTests.swift` checks it on iPhone and on the 13-inch iPad simulator. Remove that test in P15.
- **Packages:** `Packages/NookUI`, `NookKit` and `NookAI` are local Swift packages. NookAI depends on NookKit; the other two have no dependencies (04 §1). The app links all three. The widget extension links only NookUI and NookKit, because widgets never call the router. NookKit also lists macOS so `swift test` runs without a simulator.
- **Widgets:** `NookWidgets` holds one placeholder widget until P12, since a widget bundle can't be empty.
- **CI** runs on a self-hosted GitHub Actions runner on the owner's Mac (Xcode 27.0, iOS 27.0 simulators), set up in P1's CI PR. *Why:* GitHub-hosted runners may not have Xcode 27 yet, and macOS minutes cost 10× on a private repo.
- **Snapshot tests** use a small in-house helper in the NookUI tests, not a third-party library, to keep zero dependencies.
- **Lint:** SwiftLint and SwiftFormat aren't used for now. The policy greps (05 §2) enforce the hard rules. Add a linter if the style drifts.

*Affects:* CLAUDE.md (layout, commands), README, 05 §2, the roadmap P1.

**D32 · 2026-10-05 · Accepted** — **The app shell's SwiftUI mechanisms (D2, D26, D29), checked in the iOS 27.0 SDK (Xcode 27.0, 27A266a) and on the iPhone SE and 13-inch iPad simulators.**
- **Capture button:** an `.overlay(alignment: .bottomTrailing)` on each tab's content, not `tabViewBottomAccessory`.
  - The overlay keeps it in the content column, so on regular width it never sits over the sidebar (01 §1.5).
  - D26 rejected the accessory placement: it takes about 60 pt of content on iPhone SE, and Apple meant it for ongoing content.
  - Tab roots add a bottom content margin the height of the button, so the end of a scroll view can always clear it.
  - **Where it shows (from the boards):** on the tab roots and on Home's Room, Spot and Item screens. Other pushed screens (history, Warranties, Lent out, the Settings pages) don't show it. On compact width it's also left off Find, where the search field sits at the bottom of the screen; the iPad Find board keeps it. The overlay goes on a root's own content, not around its navigation stack, so pushed screens don't inherit it. 01 §1.2 only said "hidden on capture, paywall and lock screens", so it now matches.
- **C-01 presentation:** `.popover` anchored to the button, with `.presentationCompactAdaptation(.sheet)` and a medium detent. That gives a popover on regular width and a sheet on compact width from one modifier (D29). The menu is a stack, not a `List`, so the popover sizes to fit.
- **Tabs:** `TabView` with `.sidebarAdaptable`, with Find as `Tab(role: .search)`.
  - **`defaultTabBarPlacement(.sidebar)`** (new in iOS 27, next to iOS 18's `defaultAdaptableTabBarPlacement`) shows the sidebar on iPad landscape. Portrait floats the tab bar at the top, matching the P0b boards.
  - **`tabViewSearchActivation(.searchTabSelection)`** focuses the search field whenever Find is chosen, including from ⌘2 and ⌘F.
  - The selected tab is `@SceneStorage`.
- **Commands** reach the window through `focusedSceneValue` bindings (`selectedTab`), not closures: Swift 6 warns that closures in focused values invalidate on every update. ⌘1–⌘4 pass in an XCUITest on the iPad simulator. The hardware-keyboard checks of ⌘⌫ and the menu bar are in the P1 close (D30).
- **Titles:** SwiftUI has no modifier for the navigation-bar title font. `NookAppearance.configure()` sets the rounded `display`/`headline` styles and `textPrimary` through the UIKit appearance proxy once at launch (03 §8.8).

*Affects:* `Nook/App`, `Nook/Features/Capture`, 01 §1.5.

**D33 · 2026-10-05 · Accepted (2026-10-05, product owner)** — **How P1's manual checks were settled.** The owner chose not to run the hands-on checks now, so each is replaced by an automated check or waived:
- **Accessibility Inspector audit → automated.** `AccessibilityAuditTests` runs XCUITest's `performAccessibilityAudit()` (labels, hit regions, Dynamic Type clipping, traits) on Home, Reports, Settings and Appearance in CI on every PR. Later phases add their screens to it. **Contrast is excluded from the audit:** it samples rendered pixels and flagged `textSecondary` on `surface` (6.2:1 by the formula). `check_tokens.py` proves every token pair exactly instead. On iPad it also skips the Dynamic Type issues it raises for the system floating tab bar's fixed-size labels, which UIKit sizes itself and serves through the Large Content Viewer. Its first CI run also found a real bug: `NookTextField` didn't expose its label to VoiceOver (fixed).
- **⌘⌫ with a hardware keyboard → D30's fallback.** It was never confirmed (XCUITest can't fire it). Delete keeps its menu item, disabled until P3, and P3 adds the swipe and context-menu actions. The debug toast probe is removed. If ⌘⌫ later proves to work on a real iPad, nothing needs to change.
- **iPad menu-bar screenshot → waived.** The command menu is covered by D30's menu-system read and the ⌘1–⌘4 UI test.
- **Cold launch under 400 ms on a real iPhone 15 → deferred to P13**, where every PRD §9 budget is measured on devices. `LaunchPerfTests` tracks the trend on the simulator.
- **Reduce Transparency and the Liquid Glass slider → deferred to P13's accessibility audit.** The snapshots already cover Increase Contrast.
- **Stage Manager resize → waived.** The tab is kept in `@SceneStorage`, and the iPad mini and both orientations are covered by UI tests.

*Why:* keep the phases moving without the owner's hands-on time; each check either runs automatically from now on or has a named later phase. *Risk accepted:* nobody has used a hardware keyboard with Nook yet. *Affects:* the P1 QA report, the roadmap P1 status, P13's audit list.

**D34 · 2026-10-05 · Accepted** — **Containers can sit on a room's floor (refines D3).** D3 said a container is a spot with a parent spot. The H-05 board says "A container sits in a room or a spot. It can't go inside another container", and its Inside picker offers the room itself. Following the board:
- `Spot` stores its kind (`kindRaw`: spot or container), which H-05's Type picker needs anyway.
- **Spots** are always top-level in a room and can hold containers.
- **Containers** sit on the room (`parent == nil`) or inside a spot, never inside another container, and hold only items.
- Turning a spot into a container needs it to hold no containers. Turning a container into a spot brings it out onto the room.
- The rules live in `RoomService` (`addContainer`, `place`, `setKind`), with tests.

*Why:* a box on the garage floor is common, and forcing a "Floor" spot just to hold it is busywork. Nesting stays at one level, as PRD F1 says. *Affects:* 04 §4 (Spot gains `kindRaw`; schema V1 is unshipped, so no migration), 01 H-02, H-05.

**D35 · 2026-10-05 · Accepted** — **iOS 27 SDK findings from closing P2 (D23).** Each was found by a UI test that failed on the iOS 27.0 simulator:
- **SwiftData can't undo a saved delete.** `undo()` puts the rows back in the context, but the next `save()` drops them again. Undoing a saved rename works. So `RoomService.delete` turns off SwiftData's undo registration for the delete and registers its own undo, which rebuilds the room or spot from a snapshot (same `id` and `qrID`, nested containers, items relinked). D14's Undo toast, ⌘Z and shake all use it. There's no redo of a delete. P3 must keep spot photos in the snapshot once they exist, and use the same pattern for any other hard delete.
- **`TextField(title, prompt:)` exposes only the prompt to VoiceOver.** Plain fields get an explicit `.accessibilityLabel` (`NookTextField` already has one).
- **Return resigns a one-line `TextField`, and re-focusing in `onSubmit` loses fast typing.** H-04's spot field uses `axis: .vertical`, so the field stays open (F1). Finished lines become spot rows after a half-second pause in typing, and Save splits whatever is left. Rewriting the field on every newline dropped or reordered fast keystrokes ("Closet" was saved as "Coset").
- **`.tabPlacement(.sidebarOnly)` still puts tabs in the compact tab bar** (as a room tab plus More). The room tabs are `.hidden` on compact width. Removing the `TabSection` instead crashes UIKit (`_tabs_rebuildTabBarItemsAnimated`, nil insert) when a room is selected while the window narrows, which happened on the 18 Pro Max rotating to portrait. Narrowing while a room is selected returns to Home.
- **UI tests skip onboarding with `-uiTestingOnboarded`, not `-hasOnboarded`.** A launch argument named after the key shadows the App Group value, so finishing onboarding could never flip it.

*Affects:* 04 §9 (undo), 01 H-01 and H-04, `NookUITests`.

**D36 · 2026-10-06 · Accepted (product owner)** — **One PR per phase.** P1 and P2 shipped as 18 stacked PRs (#16–#33), each with its own CI run and review. That was slow to test and to merge. From P3, each phase is built on one branch, `p<N>/<phase-name>`, with a commit per task, and ships as a single PR into `main` that carries the phase's QA report. The ~400-line PR limit is dropped. Tasks still stay small, as commits.

*Why:* the owner reviews and merges per phase anyway, and per-PR test runs cost hours and disk. *Affects:* CLAUDE.md (Working in phases), `phase-work` skill.

**D37 · 2026-10-06 · Accepted (product owner)** — **A minimal quick add (C-05) ships in P3.** F2's "a photo and a name in 2 taps" needs a camera, and C-05 was a P6 screen. Capture → Add Item opens the system camera (`UIImagePickerController`); the shutter returns the photo and the editor opens with it and the name field focused, so the shutter and Save are the 2 taps. The camera permission is asked when the camera first opens (D15). With the camera denied, restricted or missing (simulators, some iPads), the editor opens straight away with "Choose from Photos" and a link to Settings. ⌘N, "Add Item Here" (H-03) and Room's Add menu use the same flow, with the room or spot pre-filled (C-01). P6 replaces the system camera with Nook's own, which also brings C-05's "Skip photo" and "Choose from Photos" buttons; in P3, Cancel in the camera closes it. UI tests pass `-uiTestingCameraFixture` (DEBUG) for a stand-in camera.

*Affects:* 01 C-05, P6 scope.

**D38 · 2026-10-06 · Accepted (product owner)** — **A minimal `LocationService.move` ships in P3.** The editor sets an item's place, and the hard rule says only `LocationService.move(items:to:source:)` writes locations. P3 ships it with the fields, one `LocationEvent` per item that actually moves, and `lastConfirmedAt`. P4 adds the Move picker (I-04), recents and history (I-05) on top; Spotlight and widget reloads join in P12. Until P4, the editor's "Where" row is a native nested menu (rooms, then spots and containers).

*Affects:* 04 §4, P4 scope.

**D39 · 2026-10-06 · Accepted (product owner)** — **The warranty field waits for P7.** I-02 lists "warranty length or end date", but warranties are their own records (D21) and the roadmap gives warranty math and reminders to P7. In P3, I-02 and I-01 have no warranty row; P7 adds the field, the card and the reminders together. The 25-item free limit also stays out of P3: `ItemService.create` marks where P11 adds `EntitlementStore.canAddItems` (D9).

*Affects:* 01 I-01 and I-02 (until P7).

**D40 · 2026-10-06 · Accepted** — **Photo and receipt files.** Files are written to the App Group as soon as they're picked, so encoding never delays Save and a killed edit loses nothing that was saved. Soft-deleted items keep their files, so Restore is complete. The 30-day purge, Delete Now and Delete All Now remove rows and files; they are final, so they confirm first ("This can't be undone.") and register no undo. Photos removed in the photo viewer undo through a snapshot (D35); their files stay. At launch, after the first frame, `BlobStore.sweepOrphans` deletes files no row references that are more than an hour old, which also cleans up after a cancelled or killed edit. Every file uses `completeUntilFirstUserAuthentication` (PRD §9). Photos are re-encoded as upright HEIC at most 4032 px on the long edge; HEIC encoding works on the iOS 27.0 simulator and macOS, so there's no JPEG fallback.

*Affects:* 04 §5.

**D41 · 2026-10-06 · Accepted** — **Home currency, for now.** D20 refers to a home currency set in Settings, which doesn't exist yet. Until it does (P10, with Reports), the home currency is the region's (`Locale.current.currency`). New items start in it; the editor's currency menu offers every ISO currency. Home's total adds only items in the home currency and says "Mixed currencies" when others exist. Nothing is converted.

*Affects:* H-01, I-02, P10.

**D42 · 2026-10-06 · Accepted** — **Receipts open in Quick Look (I-07).** `.quickLookPreview` shows images and PDFs of any length with zoom, search, share and text selection, which the mockup's custom paper view would have to rebuild. The paper look stays on I-01's receipt card thumbnail. Selectable text from Classic-scanned receipts arrives with the scanner in P6.

*Affects:* 01 I-07.

**D43 · 2026-10-06 · Accepted** — **iOS 27 SDK checks for P3 (D23).** Confirmed by building against the iOS 27.0 SDK and running on the iOS 27.0 simulator:
- `.navigationTransition(.zoom(sourceID:in:))` with `.matchedTransitionSource` gives the card-to-detail zoom, and cross-fades under Reduce Motion. The namespace is shared through the environment from each NavigationStack root (`itemNavigation()`).
- `PhotosPicker(selection:maxSelectionCount:matching:)` works inside a `Menu`, needs no permission prompt (D15), and caps the picks at the photos left out of 10.
- `.quickLookPreview(_:)` needs `import QuickLook` in the file.
- ImageIO encodes HEIC on the simulator and on macOS (`swift test`).
- `UIImagePickerController` with `.camera` still works on iOS 27; `isSourceTypeAvailable(.camera)` is false on simulators.
- Swipe actions are used only inside `List` (Recently Deleted), so D11's open question about swipe actions in other scroll views doesn't arise yet. Grid cards use context menus, which also open with a secondary click (D29).
- A bare closure in a `FocusedValues` `@Entry` warns that it may invalidate every update; ⌘N's action is wrapped in a struct.

*Affects:* `ItemSupport.swift`, `QuickAdd.swift`, `ItemDetailScreen.swift`.

**D44 · 2026-10-06 · Accepted (product owner)** — **Move picker recents, "Found it here instead" and Move Container (P4).**
- **`LocationEvent.toRoomID` is added to schema V1 in place.** V1 is merged but not on any device or TestFlight, so the owner approved editing it instead of adding V2 (data-model-change skill §3). The field is optional, so it's CloudKit-safe.
- **Recents** come from the move history: the newest 50 events, resolved to places that still exist, without duplicates or the item's current place, at most 5. They sync with the rest of the data in P11. Events from P3 without `toRoomID` resolve through their spot.
- **`found`** is a new `LocationEvent.Source`. "Found it here instead" records it, and history reads "Found here by you". It's stored as a raw string, so there's no schema impact.
- **Move Container** (H-03) moves a container to a room or a spot (never into a container, D34). Each item inside gets its own event, since its place changed too. The spot editor's "where it sits" uses the same path.

*Why:* recents that live in the data need no extra store and follow the user to their other devices. A correction reads differently from a move in "Where did it used to be?". *Affects:* 04 §4, 01 I-04, I-05 and H-03.

**D45 · 2026-10-06 · Accepted** — **iOS 27 SDK checks for P4 (D23).** Confirmed on the iOS 27.0 SDK and simulator:
- **SwiftData's own undo takes back a saved move,** including deleting the inserted `LocationEvent` at the next save. This is unlike a saved delete (D35). Moves need no custom undo, and multi-item moves are one step. Proven by `undoTakesASavedMoveBackAndDropsItsEvent` (NookKit) and `MoveTests.testMoveInTwoTapsShowsInHistoryAndUndoes`.
- **A medium detent breaks the iPad form sheet.** With `.presentationDetents([.medium, .large])`, `.presentationSizing(.form)` is ignored on iPad, and the picker becomes a bottom sheet.
  - A sheet's own content reads a compact `horizontalSizeClass` even in a wide window, so the sheet can't decide this itself.
  - RootView passes the window's size class down as `windowSizeClass`, and the picker offers the medium detent only when the window isn't regular. On regular width it's a centered form sheet (D29), checked in the iPad screenshots.
- **`.searchable(placement: .navigationBarDrawer(displayMode: .always))`** works inside a sheet's own `NavigationStack`.
- **`performAccessibilityAudit` reports false clipping at medium height.** A medium-height sheet is drawn slightly scaled, and the audit then flags the List's own section header as clipped text. The audit runs with the picker at full height. The search field's clipping is exempt, like plain text fields.

*Affects:* `LocationService.swift`, `MovePicker.swift`, `AccessibilityAuditTests.swift`.

### P5 (2026-10-06)

**D46 · 2026-10-06 · Accepted (product owner, the three choices marked)** — **Find, Classic search (P5).**
- **The search index lives in memory; there's no stored `searchText` field.** 04 §6 asked for a precomputed `searchText` on Item. Storing it would be a schema change, and every room or spot rename would rewrite every item inside to keep paths current. Instead `SearchSnapshot.docs(in:)` reads the store on a background context into value snapshots (`SearchDoc`), and `SearchIndex`, an immutable `Sendable` struct, is rebuilt from them 300 ms after each save (`SearchLibrary`). Queries run in a detached task. At 5,000 items an optimized build takes about 70 ms to rebuild and under 5 ms per keystroke on a Mac (F5's budget is 100 ms on an iPhone 15), checked in `ci.sh` with `swift test -c release`.
- **Matching:** exact, prefix, then typos (Damerau-Levenshtein 1 from 4 letters, 2 from 8; against the start of longer words only from 5 letters, because "skis" matched "skil(let)"), simple English plurals, and synonyms from `synonyms.json`. Every word must match; if nothing matches every word, the best partial matches come back, so a Classic "I put the passports in the safe" still lists Passports (01 F-04). Ranking follows 04 §6, plus +100 for an exact name, +20 for a name that starts with the query, and up to +5 for an item confirmed in the last year.
- **Classic questions:** `FindQuestion` drops English stop words and reads four intents: where (any plain search), "Who has…", "What's in…", and "Do I have…". The answer comes from `FindService` and records only: location, lent (an active `Loan`), packed (a container with `packedAt`), quantity, or a room's or spot's contents grouped by spot. With no record, there's no card. A place at the top of the results answers with its contents.
- **`FindAnswer` lives in NookKit**, not NookAI (04 §2). The app needs it before the router exists, and NookAI depends on NookKit, so P9's AI engine returns the same type. The `FindQuerying` protocol waits until P9 needs it as a tool; `FindService` already uses its method names.
- **The answer card says "Last confirmed Aug 3."** rather than the board's "You put them there on Aug 3.", which needs "it" or "them" for each name, and doesn't fit a correction ("Found here"). It shows the item's name above the place, because a typo search may answer with a differently spelled item.
- **"Last seen" is `lastConfirmedAt`** (set on add, move and "Found it here instead"). `Item.lastSeenAt` stays unused.
- **The value filter** matches only items priced in the home currency, with nothing converted (D41). The filters sheet says so.
- **Saved searches are a `SavedSearch` model** in schema V1, edited in place because V1 hasn't shipped (as in D44), so they sync with everything else in P11. Filters are stored as JSON. *(Product owner.)* Recent searches (the last 5) stay on the device, in App Group defaults.
- **Private items** show in results as "Private item · Unlock to see it", with no name or photo, and never answer. Until P12 adds Face ID, tapping the row opens the item; P12 puts the lock in front of that tap. *(Product owner.)*
- **Lending and warranty pieces before P7:** the lent answer card (read-only; Mark Returned arrives in P7), the Lent out and Warranty filters, and their quick-filter chips are built now. Each chip or filter row shows only when matching records exist, so nothing is a dead end. *(Product owner.)*
- **"Try asking"** uses the user's most recently confirmed non-private item ("Where's my Espresso machine?"), so trying it always gets an answer.
- **Rooms and spots open from any stack.** `itemNavigation()` now registers the `Room` and `Spot` destinations at each stack's root; Home and Room no longer register them. A second registration in the same stack would be ignored with a runtime warning once Find pushes rooms and spots.

*Affects:* 04 §4 (SavedSearch), §6; 01 F-01, F-02, F-03, F-05; `Nook/Features/Find`, `NookKit/Search`, `FindService`.

**D47 · 2026-10-06 · Accepted** — **iOS 27 SDK checks for P5 (D23).** Confirmed on the iOS 27.0 SDK and the iPhone SE simulator:
- **The search tab hides the navigation bar while its field is focused** on compact width, so a toolbar button on Find (Filters) can't be reached while typing. Since `.tabViewSearchActivation(.searchTabSelection)` focuses the field whenever Find opens (D32), Filters is also a chip inside the list: first among the quick filters before typing, and in front of the active filter chips in results. The toolbar button stays for regular width, where the bar remains.
- **`List` + `.searchable` in the search tab, with swipe actions and `onMove`,** works for saved searches (D28, D43).
- **`ModelContext.didSave`** fires for the main context's saves and drives the index rebuild; a fresh `ModelContext(container)` on a detached task reads the in-memory UI-test stores too.

- **Open, not pursued (owner's choice):** once the `lived` seed gave the audited item a tag, the audit reports "Potentially inaccessible text", with no element, on I-01's tag chips (P3, `NookFlowLayout`). Giving each tag its own label ("Tag: Coffee") didn't clear it. Find's footer, "Also searched receipts, serials and notes.", is flagged "Dynamic Type partially unsupported" as a List row and as a section footer, with or without `.fixedSize(horizontal: false, vertical: true)`.

*Affects:* `FindSections.swift`, `FindScreen.swift`, `SearchLibrary.swift`, `ItemDetailScreen.swift`.

### P6 (2026-10-07)

**D48 · 2026-10-07 · Accepted (product owner, the two choices marked)** — **Classic capture (P6).**
- **The ClassicEngine lives in NookAI now.** *(Product owner.)* NookAI gets `ClassicEngine` (Vision text reading, receipt and serial parsing), the shared result types from 04 §2 (`TextLine`, `PhotoInput`, `DocumentInput`, `ReceiptReading`, `SerialReading`), and the VisionKit wrappers (`DocumentScanner`, `BarcodeScanner`). 04 §1 puts a `CaptureService` in NookKit that calls the router, but NookKit can't depend on NookAI, so until P8 the app calls `NookAI.classic` from exactly one place per capability (`ReceiptScanScreen`, `SerialScanScreen`), and P8 swaps those for `router.engine()`. `policy-check.sh` is unchanged: its `^import (FoundationModels|Vision)` grep already catches `VisionKit`.
- **Room-scan items each get a crop** of the scan photo, padded 8%, as their photo, with `Photo.boxX/Y/W/H` set to where the crop came from (PRD §8). `ItemDraft.DraftPhoto` carries the box. The full scan photos aren't kept.
- **Document scans:** several pages are saved as one PDF; one page is a photo through `BlobStore.saveReceipt(_:)`. A PDF is read by rendering its first 5 pages, so text PDFs get boxes to highlight too.
- **A barcode scanned from the Capture menu:** if a live item has it (`ItemService.item(withBarcode:)`), "You have this" with the item's name and room, Open and Add Another; otherwise a new item with the barcode filled. No lookup: there's no network.
- **Share-sheet import is the "Open in Nook" document type** (`CFBundleDocumentTypes`, D28), not a Share Extension. The image or PDF goes to the C-06 review, then a new item.
- **Coach overlay:** on the first scan (`@AppStorage("hasScannedRoom")`), from the Tips button, and whenever the camera reads low light (ISO near its maximum). *ponytail:* no blur detection; P8's model can judge framing.
- **Selectable receipt text** comes from Quick Look's own Live Text (D49), so there's no invisible text layer.
- **Every receipt goes through the review**, including Choose File… and Choose from Photos in I-02 (P3 attached them directly), so every receipt's text is saved for search (`DraftReceipt.extractedText`) and its numbers can be tapped in.
- **The review starts on Date, and a tapped value goes to the field it fits.** 01 C-06 says a tap fills "the focused field". Amounts and dates are always highlighted, so a price tapped while Date is selected fills Price rather than being refused; then the next empty field is selected. Store's lines become tappable while Store is selected. One tap layer picks the nearest highlight within 22 pt, because printed lines sit closer than 44 pt and their tap areas would overlap; each highlight is still its own VoiceOver button.
- **Parsing rules** (tested in `ReceiptParserTests`): an amount needs cents or a currency printed with it, except on a TOTAL row (a ¥ the reader dropped). TOTAL beats SUBTOTAL, which beats line items, then tax; CASH, CHANGE and discounts rank last. Lines side by side share a row, with the photo's tilt taken out (from Vision's quadrilaterals), so "TOTAL … 708.00" pairs up on a crooked receipt. Numeric dates use the locale's order unless a part over 12 settles it; written months use `NSDataDetector`; dates more than a day in the future or before 1980 are dropped.
- **Fixtures are synthetic for now, real later.** *(Product owner.)* `scripts/make-receipt-fixtures.swift` renders 12 receipts (5 currencies, 7 date formats, a 24-line receipt, a 2-page PDF) and 21 damaged copies (rotated, faded, noisy). Clean: 100% of totals and dates; hard: at least 80% (today 20 of 21 totals and every date; the rotated French receipt picks its VAT line). Real photos go in `Fixtures/receipts/real/` with their JSON. *Known limit:* text recognition often reads a printed ₹ as a 7 or a 2, so the Indian fixture prints "Rs.", as thermal printers do.
- **Two-step and naming details:** the menu commands' `AddItemAction` is now `MenuAction` (⌘N and ⇧⌘N). `NookColor.cameraFeed` (black in both modes) sits behind live camera feeds. The Capture menu (C-01) isn't in the accessibility audit: it's a medium-only sheet, which the audit draws scaled and calls clipped (D45).

*Affects:* 01 C-01, C-02, C-04, C-05, C-06, C-07, C-08, I-02, I-07; 04 §1–§2; `Nook/Features/Capture`, `NookAI`, `ItemService`.

**D49 · 2026-10-07 · Accepted** — **iOS 27 SDK checks for P6 (D23, D11).** Confirmed on the iOS 27.0 SDK (Xcode 27.0, 27A266a) and the iOS 27.0 iPhone SE simulator:
- **`RecognizeTextRequest`** (the Swift Vision API) works as documented: `recognitionLevel = .accurate`, `usesLanguageCorrection`, `perform(on: CGImage)`. Each `RecognizedTextObservation` gives `topCandidates(1).first?.string`, `confidence`, and `boundingBox.cgRect`, normalized with a **lower-left** origin. It runs on the simulator (a rendered "TOTAL 708.00" came back exactly, confidence 1.0), so receipt fixture tests run in CI.
- **`VNDocumentCameraViewController.isSupported` is `true` on the simulator, which has no camera.** So it can't decide alone: the document camera is offered only when `isSupported` and a video `AVCaptureDevice` exists.
- **`DataScannerViewController.isSupported` is `false` on the simulator** (`isAvailable` is `true`). C-07 shows manual entry there.
- **`DataScannerViewController` has no torch API.** The torch button sets `AVCaptureDevice.torchMode` on the default video device while the scanner runs; whether the two coexist is an owner device check.
- **`AVCaptureSession.wasInterruptedNotification` / `interruptionEndedNotification`** and `AVCaptureSessionInterruptionReasonKey` are there, so the camera shows "Camera paused" and resumes by itself. Low light is read from `AVCaptureDevice.iso` against `activeFormat.maxISO`.
- **Quick Look Live Text:** `ImageAnalyzer.isSupported` is `true`, and Quick Look runs the same analysis on images (and on image-only PDF pages since iOS 17), so scanned receipts are selectable in I-07 with no text layer of our own (D42). Owner device check.
- **"Open in Nook"** uses `CFBundleDocumentTypes` (`public.image`, `com.adobe.pdf`, rank Alternate) with `LSSupportsOpeningDocumentsInPlace` = NO, so the system copies the file into the inbox and `.onOpenURL` receives it. Owner device check from Photos and Files.
- **`AVCaptureDevice.default(for: .video)` is `nil` on the simulator**, while `UIImagePickerController.isSourceTypeAvailable(.camera)` says `true` (P5 notes). `NookCamera.isUsable` now checks for a device, so the simulator takes the Photos path without the fixture flag.

*Affects:* `NookAI/Scanners`, `NookAI/ClassicEngine`, `Nook/Features/Capture`, `Info.plist`.
