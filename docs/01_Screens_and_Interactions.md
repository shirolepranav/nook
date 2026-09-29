# Nook — Screens, UI Elements & Interactions

This document lists every screen and state and what each interaction does. It is the build contract for UI work.

- Scope comes from [00_PRD.md](00_PRD.md) (the `F#`, `US#` and `J#` IDs).
- Resolved conflicts are in [decisions.md](decisions.md) (`D#`).
- Visual specs are in [03_Design_System.md](03_Design_System.md).

**Tags:**
- `[AI]` means Apple Intelligence iPhones only.
- `[Manual]` means the classic path that works on every iPhone.
- `[Pro]` means the feature is gated by the Pro unlock.
- `[Verify in SDK]` means the API name is unconfirmed (D11).

Every screen section lists: **Purpose · Elements · Interactions · States · Adaptive · A11y · Traces**.

---

## 0. Global conventions (apply to every screen)

- **Shell (D2):** a `TabView` with 4 tabs, each owning its own `NavigationStack`: **Home · Find (`role: .search`) · Reports · Settings**. At regular width (Duo inner, Pro Max landscape) the tabs become a sidebar via `.tabViewStyle(.sidebarAdaptable)` / `.defaultTabBarPlacement(.sidebar)`, and Home becomes a `NavigationSplitView`.
- **Capture button:**
  - A floating Liquid Glass button, visible on Home, Room, Spot and Find. It is hidden inside editors and sheets.
  - Tapping it opens the Capture menu (§4.1).
  - Long-pressing it jumps straight to Scan room.
  - Its accessibility label is "Capture".
- **Other capture entry points:** empty-state CTAs, the app-icon Quick Action, the Control Center control, the Action button, Siri/Shortcuts (`ScanRoomIntent`, `AddItemIntent`), and the widget.
- **Standard states on every data screen.** These are designed screens, each with an illustration, one sentence and one action:

| State | Rule |
|---|---|
| Loading | Skeleton "paper" cards. Never show a spinner for more than 300 ms. |
| Empty | Illustration + one sentence of value + primary CTA. |
| Error | Plain-language reason + Retry. Never a raw error code. |
| Offline | Irrelevant for core use (the app is local-first). Show a non-blocking note only for iCloud sync and StoreKit. |
| Success | A toast on `surfaceRaised` + a haptic. Undo where it is reversible. |

- **Destructive actions:**
  - A confirmation dialog anchored to the control, labelled explicitly ("Delete 3 Items").
  - Deleted items go to Recently Deleted for 30 days, and an Undo toast shows for 5 s (D14).
- **AI results are always suggestions.** They are editable, removable and undoable. Nothing is saved, and no item is moved, without an explicit user tap (PRD §6).
- **The AI/Manual parity rule.** The two paths share the same screen skeleton. Only the auto-filled content differs. The user never sees an "AI unavailable" error; the manual path appears silently.
- **Free limits (D9):**
  - Hitting a limit shows the paywall *at the moment of value*: the 26th item, the 4th reminder, or Export.
  - Existing data is never locked.
- **Private items:**
  - A lock glyph appears on the card.
  - Content is blurred until Face ID or Touch ID passes.
  - Private items never appear in Spotlight, Siri suggestions or widgets.
- **Hide values:** a Settings toggle plus a quick toggle in the Home toolbar menu. It replaces every currency value with "•••" for screen sharing (F11).
- **Tap targets are at least 44×44 pt.** Icon-only controls have accessibility labels.
- **Forms:**
  - `.submitLabel(.next)` with `@FocusState` moving focus from field to field.
  - A "Done" button in the keyboard toolbar.
  - Validation shows inline under the field, never as an alert.
- **State restoration:** the selected tab, the navigation path and the scroll position all survive relaunch and a Duo fold/unfold (PRD §4 rule 5).

---

## 1. Launch & lock

### 1.1 Launch screen
- A warm `canvas` background with a centered app mark.
- Then: App Lock (if enabled) → the restored tab, or Onboarding on first run.

### 1.2 App Lock (F11)
- **Elements:** an opaque privacy cover on `canvas`, the app mark, an "Unlock Nook" button, and a "Use Passcode" link.
- **Interactions:**
  - Face ID or Touch ID (Touch ID on SE and Duo) is invoked automatically when the screen appears.
  - Success: cross-fade in with a `.success` haptic.
  - Failure: a shake (a color pulse under Reduce Motion) with an `.error` haptic.
  - Repeated failures fall back to the device passcode.
- **Rules:** content is never visible before unlock, and the app-switcher snapshot is always covered. The lock follows the "Lock after" setting: Immediately, 1 min, 5 min or 15 min.
- **Edge cases:** if biometrics aren't enrolled, use the passcode and show a one-line explainer.

---

## 2. Onboarding (under 60 s; PRD §3)

| # | Screen | Elements & interactions |
|---|---|---|
| 2.1 | Welcome | Hero illustration (a soft home shelf) and the line "Know what you own and where it is." "Get Started". |
| 2.2 | Pick your rooms | Suggested room chips: Kitchen, Living room, Bedroom, Bathroom, Office, Garage, Basement, Storage. Tapping a chip toggles it with a `.selection` haptic. "+ Add your own" opens a name field. Each room gets a default symbol and room color. "Continue" requires at least 1 room. |
| 2.3 | First room | "Scan your first room" (primary) and "Add an item by hand" (secondary). "Skip for now". **No permission prompt appears until the user taps Scan** (D15). |
| 2.4 | Guided first scan | Room scan (§4.2) with the **coach overlay**: a live hint like "Step back a little so the whole shelf fits". It runs once and can be re-enabled in Settings. |
| 2.5 | Done | The first card "settles" onto the Home shelf with the `celebrate` motion. |

- **States:** Skip is allowed from 2.2 onward, and the app lands on an empty Home. If the user denies the camera at 2.3, route to "Add an item by hand".
- **A11y:** VoiceOver announces the step ("Step 2 of 3"). Chips are toggle buttons with a selected trait.
- **Metric:** the median time to first room documented is under 3 min (PRD goals). Instrument this locally only, in debug and TestFlight builds, with no analytics SDK.
- **Traces:** US1, US2, PRD §3 Onboarding.

---

## 3. Tab: Home (rooms → spots → items)

### 3.1 Home dashboard
- **Purpose:** the shelf of your home. Rooms as cards, your total value, recent additions, and warranties that need attention.
- **Elements:**
  - Nav bar: a large rounded title ("Home"). Trailing items: `+ Room` and an overflow menu (Hide values, Select, Recently Deleted).
  - Card 1, **Total value**: the sum of item prices in the value font (rounded, monospaced digits), the item count, and "N items missing photos or receipts". Tapping it opens a filtered Find.
  - Card 2, **Warranties ending soon**: shown only if any warranty ends within 30 days. A horizontal carousel of honey chips (the item photo plus "Ends in 12 days"). Tapping a chip opens Warranty Detail (§6.4). "See all" opens Reports → Warranties.
  - Card 3, **Rooms grid**: a room photo card per room, showing the room color, symbol, name, item count and value. This is the main content. Photos are the interface.
  - Card 4, **Recently added**: a horizontal strip of item photo cards.
  - Card 5, **Lent out**: shown only if any loans are active. "3 things are lent out", which opens the Find filter.
- **Interactions:**
  - Tap a room card → Room Detail (§3.2).
  - Long-press a room card → Rename, Change icon & color, Reorder, Delete.
  - Drag to reorder rooms (`.reorderable()` [Verify in SDK], or the `onMove` fallback), with an `.alignment` haptic when a card snaps into place.
  - Pull to refresh re-runs iCloud sync if it's enabled; otherwise pull to refresh isn't offered.
- **States:**
  - Empty (new user): one welcoming card, "Nothing here yet. Scan a room to fill it in 30 seconds." with the Scan room CTA.
  - Loading: skeletons.
  - Sync error (Pro): the inline line "Couldn't sync. Your data is safe on this iPhone." with Retry.
- **Adaptive:**
  - Compact: 2-column room grid.
  - Duo outer (short height): a compact **Quick find** bar at the top and 2 rows of cards. Nothing important sits below the fold.
  - Regular: a `NavigationSplitView` with the room list in the sidebar column and the room's item grid in the detail column.
- **A11y:** each room card reads "Kitchen, 42 items, 3,180 dollars". Card containers use `.accessibilityElement(children: .combine)`.
- **Traces:** J2, J3, J4, F1, F4, F7.

### 3.2 Room Detail (F1)
- **Elements:**
  - A header in the room color with the symbol, name, item count and value.
  - A **Spots** row: horizontal chips, one per spot and container, plus "+ Spot".
  - An **Items** grid of photo cards grouped by spot, with section headers showing the spot name and its optional spot photo thumbnail.
  - Toolbar: a grid/list toggle and a Select button.
- **Interactions:**
  - Tap an item → Item Detail (§3.4), using a **zoom transition** from the card (a cross-fade under Reduce Motion).
  - Tap a spot chip → Spot Detail (§3.3).
  - Swipe or long-press an item → Move, Lend, Mark private, Delete.
  - Select mode shows a bottom toolbar: Move (F6 multi-select), Tag, Export, Delete.
- **States:**
  - Empty room: "Nothing here yet. Scan this room to fill it in 30 seconds." with **Scan this room** (primary) and "Add by hand".
  - Empty spot section: hidden.
- **Adaptive:**
  - Compact: 2 columns (3 on Pro Max landscape).
  - Regular: 4–5 columns, and Item Detail opens in the detail column instead of covering the grid.
- **Traces:** F1, F2, F6, J2.

### 3.3 Spot / Container Detail (F1, F8)
- **Elements:**
  - A breadcrumb (Room → Spot → Container) and the spot photo (tap it to replace).
  - A list of child containers (one level only, D3).
  - An items grid.
  - For containers: a **QR label** button (§3.9) and a "Packed" date if one is set.
- **Interactions:** "+ Container" (only offered on a top-level spot), Rename, Move container (moves all its contents and logs a LocationEvent for each item), Delete (a dialog asks where the items should go).
- **Traces:** F1, F8, J5.

### 3.4 Item Detail (F2)
- **Elements, top to bottom:**
  - **Photo carousel** (up to 10 photos, page dots). Tapping a photo opens a full-screen viewer with pinch and double-tap zoom and swipe-down to dismiss. With no photo, show an "Add photo" tile.
  - **Title block:** the name (title font, rounded), category, tags, and a lock glyph if the item is Private.
  - **Location card** (the most prominent card):
    - The breadcrumb "Office → Desk → Second drawer", the spot photo, and "Last confirmed Aug 3".
    - **Move** (primary) and "It's here ✓", which updates `lastConfirmedAt` with a `.success` haptic.
    - If the item is lent: "Jordan has it since Sep 12 · due Oct 1" with "Mark returned".
  - **Key facts:** quantity, price (currency), purchase date, store. `[AI]` Estimated replacement range, always labeled "Estimate".
  - **Identifiers:** brand, model, serial (monospaced, with a copy button), barcode. "Scan serial" opens §4.5.
  - **Warranty:** a status pill, the end date, a days-remaining ring and the reminders. Or "Add warranty".
  - **Receipts:** thumbnails that open in Quick Look. "Add receipt".
  - **Notes.**
  - **Location history:** a collapsed list of LocationEvents (from → to, date, source: manual, Siri or AI).
  - **Find My shortcut** (valuables only, optional): opens the Find My app. We can't read AirTag locations (PRD §6).
- **Toolbar:** Edit, Share (the single-item PDF), and an overflow menu (Lend, Mark private, Duplicate, Delete).
- **Interactions:** long-press the serial to copy it, with a "Copied" toast and a `.success` haptic.
- **Adaptive:** at regular width the item opens beside the grid. When the Duo is half-folded, the photo sits above the hinge and the details below (`ReservedRegion` [Verify in SDK]).
- **A11y:** the photo carousel is a single adjustable element ("Photo 2 of 5"). Every card has a heading trait. The Move button is reachable within 2 swipes of the title.
- **Traces:** F2, F4, F6, F7, US3, US4, J1, J6.

### 3.5 Item Editor (F2)
- A full-screen sheet with Cancel and Save. It is used for manual add, for editing, and for reviewing AI results.
- **Sections:**
  - **Photos:** add, reorder and delete, 10 max. At the limit, the Add tile is disabled with the hint "10 photos max".
  - **Basics:** name (**the only required field**; it autocompletes from the 500 common items plus the user's own past items), location (the picker from §3.6, defaulting to the current room/spot context), category, tags (token field), quantity.
  - **Purchase:** price (locale currency, decimal pad), date (compact DatePicker), store, and receipt (attach from camera, Photos or Files).
  - **Identifiers:** brand, model, serial with **Scan**, barcode with **Scan**.
  - **Warranty:** a toggle, then a length preset (1y / 2y / 3y / custom) **or** an end date. The end date is computed as purchase date + length. Reminders go out 30 and 7 days before the end (D13).
  - **More** (collapsed; progressive disclosure): notes, Private toggle.
- **Validation:**
  - A purchase date in the future shows a warning but doesn't block saving.
  - A duplicate serial shows a warning ("You have another item with this serial") but is still allowed.
- **Save:**
  - Save is disabled until the item has a name. A photo plus a name is enough, which meets **F2's "saves in 2 taps"**.
  - On success the sheet dismisses, the card "settles" into the grid, a toast shows "Added to Kitchen · Add another", and a `.success` haptic plays.
- **Cancel with changes** asks "Discard changes?". A draft is saved automatically when the app backgrounds.
- **Free limit:** saving the 26th item shows the Paywall (§8) instead of saving. The draft is kept.
- **Traces:** F2, F4, US2.

### 3.6 Move picker (F6)
- **Elements:**
  - A medium-detent sheet with a search field.
  - A **"Recent" section of the last 5 used locations** at the top.
  - The full Room → Spot → Container tree below.
  - "+ New spot".
- **Interactions:**
  - Tapping a destination moves the item immediately (**tap 1 = Move, tap 2 = destination**), plays an `.alignment` haptic, and shows the toast "Moved to Bedroom → Safe · Undo".
  - Each move writes a LocationEvent (source `manual`) and sets `lastConfirmedAt = now`.
  - With multi-select, one pick moves every selected item.
- **Entry points:** Item Detail, Find results, the answer card (§5.2), a widget, Siri (`MoveItemIntent`), and the Lock Screen control.
- **Traces:** F6, US4.

### 3.7 Lend sheet (F7)
- **Elements:** a "Lent to" field (a typed name, or **Choose contact**, which triggers the Contacts permission on first use), date lent (defaults to today), optional return date, and a "Remind me" toggle.
- **Result:** a "Lent" badge on the item card and an entry in the "Lent out" filter. The reminder fires on the return date and counts toward the Free limit of 3 reminders.
- **Mark returned:** sets `returnedDate` and clears the badge.
- **Traces:** F7, J6.

### 3.8 Room / Spot editor (F1)
- **Fields:** name, an SF Symbol grid (hierarchical rendering), a room color swatch (8 soft colors), and for spots an optional spot photo and parent spot.
- **Acceptance:** creating a room with 3 spots takes under 30 s. After saving a spot, focus returns to "+ Spot".

### 3.9 QR label (F8)
- **Elements:**
  - A preview of the label: the QR code, container name, room, and item count.
  - Size presets: small sticker, 4×6 in, and A4 sheet.
  - **Print** (`UIPrintInteractionController`) and **Share** (PDF or PNG).
- **Behavior:** the QR code encodes `nook://spot/<qrId>` [Verify in SDK: whether the system Camera opens custom schemes directly]. Scanning it with the system Camera opens Spot Detail for that container. An unknown ID shows "This label isn't in your Nook".
- **Traces:** F8, J5.

### 3.10 Recently Deleted (D14)
- Rows show the days remaining. Swipe to Restore or Delete Now. "Delete All" asks for confirmation.
- Items are purged automatically on launch once they are older than 30 days.

---

## 4. Capture (floating button)

### 4.1 Capture menu
- A medium-detent sheet, or a glass menu anchored to the button, with 4 large tiles: **Scan room** · **Add item** · **Scan receipt** · **Scan barcode**. The destination defaults to the current room/spot context and can be changed with a chip at the top.
- Every capture tile runs the camera pre-check (§10).

### 4.2 Room scan (F3, US1)
- **Flow:** camera → capture one or more photos → the review screen.
- **Camera screen:**
  - A live preview, a shutter, a thumbnail tray of captured photos, "Done", and a torch toggle.
  - Coach overlay hints ("Step back a little so the whole shelf fits"; "More light helps").
  - Capturing a photo plays an `.impact(weight: .light)` haptic.
- **Review screen, `[AI]` path:**
  - The photo on top. Below it, **item cards stream in** as the model detects each one.
  - For each detected item: a soft outline draws on the photo and a light haptic plays, **one after another** (the detection cascade in 03 §9).
  - Each card shows the cropped photo, the name, the category and the brand if one is visible.
  - Each card has **Accept** (on by default), **Edit** (opens the Item Editor pre-filled) and **Remove**.
  - Tapping an outline highlights its card, and tapping a card highlights its outline.
  - "Missed something?" switches to manual tagging on the same photo.
  - The first card appears in under 2 s, and a full scan of about 10 items takes under 8 s.
- **Review screen, `[Manual]` path** (and the AI fallback):
  - The same photo. The user **drags to draw a box** around an item, then types a name.
  - Suggestions come from the 500-item list and the user's own past items, shown as chips above the keyboard.
  - Each box becomes a card in the same list UI.
  - Target: 8 items saved in under 2 min.
- **Footer:** "Save all (6)", which saves the accepted cards into the chosen room/spot, plus a destination chip.
  - Success: a "Saved 6 items to Kitchen" toast with a `.success` haptic, and the cards settle into the room grid.
  - Crossing the Free limit: save up to 25 items, then show the Paywall for the rest. The rest stay as a draft.
- **States:**
  - Processing: shimmer on the placeholder cards.
  - AI failure (model busy, guardrail, or a timeout over 20 s): **silently switch that photo to manual tagging**, with the one-line note "Tap items to add them."
  - No items found: "Couldn't spot items here. Tap to add them yourself."
- **Adaptive:** when the Duo is half-folded, the camera or photo sits on the top half and the cards on the bottom half.
- **A11y:** every detected card is a VoiceOver element with Accept, Edit and Remove as custom actions. Manual box drawing has an alternative: "Add item without drawing" adds a card for the whole photo.
- **Traces:** F3, US1, US2, PRD §8 pipeline.

### 4.3 Add item (single)
- Take a photo, or Choose from Photos (`PhotosPicker`, no permission needed), or Enter manually.
- `[AI]`: the photo fills in the name, category, brand and estimated condition. The fields show a subtle "Suggested" tint until the user edits them.
- `[Manual]`: the photo goes into the Item Editor, and the name field autocompletes.
- Then the Item Editor opens (§3.5).
- **Traces:** F2, US2.

### 4.4 Scan receipt (F4)
- The system document camera (`VNDocumentCameraViewController`: auto-capture, multi-page, crop), or Import from Files or the share sheet (image or PDF).
- **Receipt Review:**
  - `[AI]`: store, date, price and warranty length are extracted into fields. Low-confidence fields get a honey "Check this" badge.
  - `[Manual]`: Vision OCR **highlights prices and dates on the receipt image**. The user taps a highlighted value to drop it into the focused field.
  - Both paths: tapping a highlight links it to its field, and tapping a field shows its source highlight. "Rescan" is available.
  - Output: attach the receipt to an existing item (the default when opened from an item), or "Create item from receipt".
- **States:** Processing (shimmer), and Failure: "Couldn't read this receipt. Save it as an image and fill in later." (The image is never lost.)
- The extracted text is stored on the Receipt so Find can search it.

### 4.5 Scan serial / model (F2)
- The camera or a photo of the sticker.
- `[AI]`: the model finds and labels the serial number, and the user confirms.
- `[Manual]`: all OCR lines are listed, and the user taps the right one.
- Serials are shown monospaced and middle-truncated if long.

### 4.6 Scan barcode
- `DataScannerViewController` (UPC/EAN) with a reticle, guidance label, torch and close button.
- On success: a `.success` haptic, a freeze frame, and a bottom card with "Use code".
- On devices where the data scanner isn't supported, fall back to manual entry.
- There is no online product lookup (a PRD non-goal). The code is stored and searchable.

---

## 5. Tab: Find (F5, PRD §6)

### 5.1 Find home & results
- **Elements:**
  - One search field with the placeholder: `[AI]` "Search or ask 'Where are the passports?'" / `[Manual]` "Search items, rooms, spots".
  - Before any typing: recent searches, **saved searches**, and suggested tokens (rooms, categories, "Lent out", "Warranty ending", "No receipt").
  - **Filters:** room, category, tag, value range, warranty status, lent out, and last seen ("not seen in 2 years", J7).
- **Results:**
  - Instant as you type: **under 100 ms at 5,000 items** (F5).
  - Sections: Items, Rooms & Spots, Receipts (matched OCR text).
  - Matches are highlighted.
  - Search tolerates typos and uses the synonym list ("fob" → "key").
  - Each item row shows its breadcrumb and a **Move** button inline.
- **Save search:** "Save this search" stores the query and filters, and it appears on Find home.
- **No results:** "No matches for 'x'" with "Add 'x' as a new item".
- **Traces:** F5, J1, J2, J7, US3.

### 5.2 Answer card ("Where is…?")
- **Trigger:**
  - `[AI]`: a question phrased in the field, or a single strong match.
  - `[Manual]`: an exact or top match.
- **Elements:**
  - The item photo, the spot photo, and the **breadcrumb** ("Office → Desk → Second drawer").
  - "You put them there on Aug 3", plus the **last confirmed** date (always shown).
  - Buttons: **Move** and **"Found it here instead"**, both of which open the Move picker. **"It's here ✓"** confirms the location.
- **Variants:**
  - Lent: "Jordan has it since Sep 12".
  - Packed (in a container with a packed date): "Box 14, packed Jun 2".
  - History question: "It used to be in Garage → Shelf (until Jul 4)".
  - Room question: the items grouped by spot.
- **AI rule:** the answer text is phrased from database records only. If there's no record, say "I don't have a location saved for that." **Never guess.**
- **Traces:** PRD §6, US3.

### 5.3 Move confirmation card `[AI]`
- **Trigger:** a statement like "I put the passports in the safe".
- **Card:** "Move **Passports** to **Bedroom → Safe**?" with **Move** (primary) and Cancel. Ambiguous items or locations show a choice list.
- **Nothing moves without the tap.** On confirm, write a LocationEvent (source `ai`) and show a toast with Undo.
- `[Manual]` iPhones: statements are treated as searches, and the user moves items with the Move button.

---

## 6. Tab: Reports (F9, F4)

### 6.1 Reports home
- Rows: **Insurance report** · **Warranties** · **Lent out** · **Export CSV** · **Backup (.nookbackup)**.
- Each row has a subtitle, for example "182 items · $24,310" or "5 active · 2 ending this month".

### 6.2 Insurance report builder `[Pro]` (Free: a watermarked preview of page 1)
- **Scope:** all items, a room, a category, a selection, or value over X.
- **Include:** photos, receipts (appendix), serials, warranties. `[AI]` Optional one-paragraph summary per room.
- **Cover:** policy holder, address, policy number (all optional; stored locally).
- **Generate → Preview:**
  - A paged PDF with **Share** (system share sheet only) and **Save to Files**.
  - While generating: "Rendering 42 of 180 items", with Cancel.
  - On failure: Retry, with the suggestion "Try without receipts".
  - Budget: 500 items in under 20 s.
- **Free:** tapping Export shows the Paywall (§8). The preview is still viewable (D9).

### 6.3 Warranties list (F4)
- A segmented control: Ending soon · Active · Expired · All. Header: "5 active · 2 ending this month".
- Rows are grouped by month. Each row shows a thumbnail, the item, the end date and a days-left pill:
  - honey for 30 days or less
  - danger for 7 days or less
  - gray once expired

  The pill always includes an icon and text.
- Swipe to "Snooze reminder 1 week". Tapping a row opens Warranty Detail.
- **Empty state:** "No warranties yet. Add one from any item." with "Choose item".

### 6.4 Warranty detail / editor
- **Detail:** a coverage ring, start and end dates, type (manufacturer / extended / store), provider, policy number (copy), proof documents (receipts), and the reminder schedule. **Export proof pack** produces the item's PDF with its receipts (D4).
- **Editor:**
  - Type, provider, start date (defaults to the purchase date), then length **or** end date.
  - Cost, policy number, contact.
  - Reminders: 30 and 7 days before by default, with 90 and 1 day available. Time of day defaults to 9:00 local.
- **Edge cases:** if the warranty is already expired when created, show the note "This warranty has ended" and schedule no reminders. Reminders use the current time zone and handle DST.

### 6.5 Lent out
- The list of active loans with the person, lent date and due date. Overdue loans are marked honey.
- Swipe to "Mark returned". A returned-loans section is collapsed at the bottom.

### 6.6 Export CSV `[Pro]` · Backup `[Pro]`
- **CSV:** all fields, UTF-8, one row per item. It opens correctly in Numbers and Excel.
- **Backup:** exports a `.nookbackup` file (D12) through the share sheet. Restore offers **Replace** or **Merge** (merging dedupes by UUID), always after a confirmation.

---

## 7. Tab: Settings

An inset grouped list:
- **Nook Pro:** status, or the upgrade row (Paywall), plus Restore Purchases.
- **iCloud Sync `[Pro]`:** On/Off, then status (Synced · time / Syncing / Off / Error with the reason: signed out, storage full), and "Sync now".
- **Security:** App Lock toggle, Lock after, Hide values.
- **Notifications:** warranty reminder lead times, time of day, loan reminders. If notifications are denied: "Notifications are off for Nook" with "Open Settings".
- **Appearance:** System / Light / Dark, the **accent picker (6)** (D5), and the alternate app icon.
- **Data:** currency, categories & tags manager (add, rename, merge, delete), Recently Deleted, and Backup & Restore.
- **Help:** re-run the scan coach, tips, and contact support (a mailto link, no SDK).
- **About:** privacy page (plain language, PRD §9), version, acknowledgements.

---

## 8. Paywall (D9, PRD §7)

- **Triggers:** only when adding a **26th item**, saving a **4th reminder**, tapping **Export** (the PDF or CSV), or turning on **iCloud sync**. Never on launch.
- **Layout:** one screen, one price, one button.
  - A headline with **the user's own numbers**: "You've documented 25 items worth $4,380."
  - 3 benefit rows: Unlimited items · Insurance PDF & CSV · iCloud sync & backup.
  - The native StoreKit `ProductView`, showing the $14.99 introductory price during the first 2 weeks, then $19.99.
  - **Restore Purchases**, terms and privacy links. The close button is always visible.
- **States:** loading product · purchasing · pending (Ask to Buy) · success (confetti-free: a `.success` haptic, a check drawn on, then return to the interrupted action) · failure (plain reason and retry) · offline (the cached entitlement is used, with a "Connect to purchase" note).
- **Rule:** after closing the paywall, the user lands back where they were with their data intact. Free users can always view, search and delete everything.

---

## 9. Private items (PRD §6, F11)

- **Toggle:** Item Editor → More → Private, or the item overflow menu.
- **Effects:**
  - Blur the photos and values until the user authenticates. The lock stays open for the current session.
  - Remove the item from the Spotlight index, App Intents suggestions and widgets.
  - It still appears in Find, but as a locked row until authentication.
- **Siri asking for a Private item:** reply "Open Nook to see that item" and never reveal its location without authentication.

---

## 10. Permission flows (just-in-time, D15)

| Permission | Trigger | Soft ask (our sheet, before the system prompt) | Denied state |
|---|---|---|---|
| Camera | First Scan / Take photo | "Nook uses the camera to photograph your things and receipts." [Continue] | "Camera is off for Nook" + Open Settings, with **Choose from Photos** and **Add by hand** as alternatives |
| Photos | Choose from Photos | None: `PhotosPicker` needs no permission | n/a |
| Notifications | First warranty or loan reminder saved | "Want a heads-up 30 days before this warranty ends?" [Remind me] [Not now] | A "Reminders off" chip that opens Settings |
| Contacts | "Choose contact" in the Lend sheet | None extra; the system contact picker needs no permission | Typed name only |
| Face ID | Turning on App Lock | `NSFaceIDUsageDescription` | Falls back to the passcode |

**Rule:** never show a system prompt without a user action that makes the reason obvious.

---

## 11. System surfaces

| Surface | Spec | Traces |
|---|---|---|
| Widgets (Home Screen) | Small and medium **"Warranties ending soon"**; small **"Total home value"** (respects Hide values); small and medium **"Quick find"** (tap → Find focused). Empty: "All warranties healthy". They read the App Group store read-only, **exclude Private items**, and deep-link to Warranty Detail or Find. They render correctly on Duo inner, in light, dark, tinted and clear. | F10 |
| Lock Screen / Control Center | A control that opens **Room scan**. A Lock Screen control for **Move item** (opens Find in move mode). An Action button option for Room scan. | F10, PRD §6 |
| App Intents | `FindItemIntent`, `MoveItemIntent`, `ListRoomIntent` ("What's in [room]"), `AddItemIntent`, `ScanRoomIntent`. Items and rooms are `AppEntity`s. App Shortcuts phrases are included. View annotations tell Siri which item is on screen. | PRD §8 |
| Spotlight | Items, rooms and spots are indexed (excluding Private). Tapping a result deep-links to the right detail with the back stack intact. | F5 |
| Notifications | "Your Dyson V15 warranty ends in 30 days", with actions **View** and **Snooze 1 week**. Loan: "Your drill is due back from Jordan today", with actions **Mark returned** and **Snooze**. | F4, F7 |
| Quick Actions (app icon) | Scan room · Add item · Find | — |
| Deep links | `nook://item/<uuid>`, `nook://spot/<qrId>`, `nook://room/<uuid>`, `nook://find?q=`, `nook://scan` | F8 |

---

## 12. Adaptive layout summary (PRD §4)

| Screen | Compact (slabs, Duo outer) | Regular (Duo inner, Pro Max landscape) | Duo half-folded | Duo outer (short height) |
|---|---|---|---|---|
| Home | Tab bar, 2-column rooms | Sidebar + split view: rooms list beside the item grid | — | Quick find bar + 2 rows of cards |
| Room | 2 columns (3 on Pro Max landscape) | 4–5 columns, detail beside | — | 2 columns, compact header |
| Item Detail | Pushed | Detail column | Photo above the hinge, facts below | Collapsible photo |
| Room scan | Full screen | Camera and cards side by side | Camera top, cards bottom | Camera with a card drawer |
| Find | Full screen | Results + detail | — | Field pinned at the top |

Rules:
- Size classes only. No `UIScreen.main`.
- Per-edge safe areas.
- `ConcentricRectangle` corners.
- Context is kept across fold and unfold.
- The layout must work at any Split View width.

---

## 13. Edge-case checklist (every screen owner checks these)

- **Long text:** long names wrap to 2 lines; serials are middle-truncated. Handle emoji and RTL.
- **Photos:** 0 photos, 10 photos, huge HEIC files, rotation.
- **Receipts:** PDFs over 20 MB show a warning.
- **Duplicate serials:** warn, but allow.
- **Currency:** the currency is stored per item. Handle mixed-currency totals (see 04: a "Mixed currencies" note plus a per-currency breakdown).
- **Dates and time:** time zone and DST for reminders; Feb 29; warranties already expired when created; a device clock change.
- **Data:** a full disk or full iCloud quota, sync conflicts (last writer wins, logged), the app killed mid-save (drafts), 5,000 items, 100 rooms, duplicate room names (allowed).
- **Free and Pro:** crossing the 25-item limit in the middle of a room scan.
- **Accessibility and appearance:** AX5 Dynamic Type (grids switch to lists), VoiceOver, Voice Control, Reduce Motion/Transparency, Increase Contrast, the extremes of the Liquid Glass slider, Bold Text.
- **iPhone Duo:** fold or unfold mid-flow, Split View at every width, bars on the left or right edge.
- **No AI:** the whole app must work with Apple Intelligence off, or while the model is still downloading.

---

## 14. Traceability (PRD → screens)

| PRD ID | Screens |
|---|---|
| F1 | 3.1, 3.2, 3.3, 3.8 |
| F2 | 3.4, 3.5, 4.3, 4.5 |
| F3 | 4.2 |
| F4 | 3.5, 4.4, 6.3, 6.4, 11 |
| F5 | 5.1, 11 (Spotlight) |
| F6 | 3.6, 5.2 |
| F7 | 3.7, 6.5 |
| F8 | 3.3, 3.9, 11 (deep links) |
| F9 | 6.2, 6.6 |
| F10 | 11 |
| F11 | 1.2, 7, 9 |
| US1 | 2.3–2.4, 4.2 |
| US2 | 3.5, 4.2 manual, 4.3–4.6 |
| US3 | 5.1, 5.2 |
| US4 | 3.6 |
| US5 | 6.2 |
| US6 | 6.4, 11 (notifications) |
