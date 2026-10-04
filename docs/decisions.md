# Decisions Log

Resolutions for anything the PRD leaves open, or where earlier drafts conflicted with it. **Precedence: [00_PRD.md](00_PRD.md) > this file > every other doc.** If you change a decision, add a new entry that supersedes the old one. Don't edit history.

Format: `ID · Date · Status` — Decision. *Why.* *Affects:* docs/code.

Status values: **Accepted**, **Proposed** (a PR is open and needs a lead's approval), **Superseded by Dxx**.

---

### Merge of earlier drafts (2026-09-28)
Earlier drafts of the screens, roadmap and design system were written without access to the PRD. They were called "Home Inventory & Warranty Vault" and assumed iOS 26, 5 tabs, no AI and an iPad target. We kept their craft (tokens, states, platform constraints, QA structure) and made the scope match the PRD. The entries below record every conflict.

**D1 · 2026-09-28 · Accepted** — The minimum OS is **iOS 27.0**, built with the **iOS 27.1 SDK / Xcode 27.1**. *Why:* the PRD needs Foundation Models image input and full-screen iPhone Duo support. *Affects:* project settings, and all availability checks (no `#available(iOS 26…)` branches).

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

**D23 · 2026-10-03 · Proposed** — **SDK for v1.0.** The minimum OS stays **iOS 27.0**. v1.0 builds with the **current release of Xcode 27**. The **iOS 27.1 SDK / Xcode 27.1** is needed only for v1.1 (P14, iPhone Duo). Supersedes D1's build-SDK clause once a lead approves, and needs a matching edit to PRD §8. *Why:* Foundation Models image input is in the iOS 27 SDK. Only `ReservedRegion` and the full-screen Duo layout need 27.1. D1, the PRD and the roadmap's "Correction to PRD §8" currently disagree. *Affects:* PRD §8, 04 header, CLAUDE.md "Unverified APIs", CI Xcode version.

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
