# Nook — Pages, UI & Interactions

**Source:** *Home Inventory & Warranty Vault — PRD + Technical Spec* (Sep 27, 2026, @Pranav Shirole). Section references such as "PRD §5 F3" point back to that document.
**Platform:** iPhone and iPad (D29), iOS 27.0 and iPadOS 27.0 minimum (PRD §8), built with the current release of Xcode (no beta needed). One adaptive layout from iPhone SE (4.7") to the 13-inch iPad (PRD §4).

**Release split**
- **v1.0:** everything in this document except items tagged **[v1.1 Duo]** or **[v1.2 iPad]**. Layouts adapt by size class, so iPhone Duo owners can run v1.0 on both screens; the hinge-aware poses come later.
- **v1.1 (iPhone Duo support):** items tagged **[v1.1 Duo]**: half-folded layouts, hinge avoidance, open/close continuity, and the Duo outer-screen Home layout. These need the iOS 27.1 SDK.
- **v1.2:** items tagged **[v1.2 iPad]**: drag and drop, and multiple windows (D29).

**Legend**
- **[PRD]**: stated in the PRD.
- **[Inferred]**: needed to make a stated feature work, but not spelled out in the PRD. Confirm or cut.
- **AI** / **Classic**: the two paths the capability router chooses between (PRD §5, §8). Every AI screen has a Classic twin, and the user never sees an error when the AI is unavailable.
- **Pro**: needs the one-time Nook Pro unlock (PRD §7).

---

## 1. Global conventions

### 1.1 Navigation model
| Width class | Structure | Source |
|---|---|---|
| Compact (all standard iPhones; Duo outer screen) | Bottom Liquid Glass tab bar: **Home · Find · Reports · Settings**, plus a floating Liquid Glass **Capture** button | [PRD §3 Navigation, §4 rule 1] |
| Regular (every iPad, Pro Max landscape, enlarged iPhone Mirroring, Duo inner screen) | Tab bar becomes a sidebar; two-column `NavigationSplitView` (room list beside item grid); item details open beside the grid | [PRD §4 rule 2] |

> **Interpretation note:** the PRD lists Capture as tab 3 *and* calls it a floating button. This spec treats Capture as a floating action, not a destination: one tap opens the Capture menu (C-01) from any tab. This keeps "Capture is always one tap away" (PRD §3 pillar 2). Validate in the design prototype.

- Find uses the system search tab role, so its search field gets native placement and behavior. [Inferred]
- Each tab keeps its own navigation stack and scroll position.
- **[v1.1 Duo]** Opening or closing the Duo preserves the current room and scroll position (PRD §4 rule 5).

### 1.2 Patterns that appear on many screens
| Pattern | Behavior | Source |
|---|---|---|
| **Capture button** | Floating glass button, bottom trailing, above the tab bar. Opens C-01. Shown on the tab roots and on Room, Spot and Item detail; not on other pushed screens, and not on Find at compact width, where the search field sits at the bottom (D32). Hidden on capture, paywall and lock screens. | [PRD §3] |
| **Move button** | Opens the Move picker (I-04). Present on item detail, answer cards, search results, widgets, Siri and a Lock Screen control. | [PRD §5 F6, §6] |
| **Location breadcrumb** | "Bedroom → Wardrobe → Top shelf". Tapping a segment opens that room, spot or container. | [PRD §6] |
| **Last confirmed label** | "Last confirmed Aug 3" on every location answer, so users know how fresh it is. | [PRD §6 honest limits] |
| **Private badge** | Lock glyph on Private items. Opening one requires Face ID / Touch ID. | [PRD §6, §9] |
| **Hide values** | One tap masks every price and total as "••••" for screen sharing. | [PRD §5 F11] |
| **Suggestions, not decisions** | Every AI result is editable and undoable; nothing moves or saves without a tap. | [PRD §3 pillar 4, §6] |
| **Undo toast** | After delete, move or save-all. Deletes also go to Recently Deleted for 30 days. | [PRD §3 pillar 4] |

### 1.3 Standard states (every data screen)
Each state is a designed screen with an **illustration, one sentence and one action** (PRD §3).
- **Empty:** e.g. empty room: "Nothing here yet. Scan this room to fill it in 30 seconds." → Scan room.
- **Loading:** skeleton photo cards in the warm palette; spinners only for waits under 1 second. [Inferred]
- **AI unavailable or failed:** never shown as an error. The screen quietly becomes its Classic version with the user's photo already loaded (PRD §8 step 5).
- **Error (rare: storage full, iCloud, StoreKit):** plain reason, reassurance ("Your items are safe on this iPhone"), and Retry. Copy that names the device says "iPad" on iPad (D29).
- **Offline:** not a state. The app needs no network except StoreKit and optional iCloud (PRD §9).

### 1.4 Free vs Pro gating (PRD §7)
| Feature | Free | Pro |
|---|---|---|
| Items | Up to 25 (26th triggers paywall) | Unlimited |
| Rooms, search, "Where is…?", widgets, QR labels, lending | Yes | Yes |
| AI room scan and receipt reading | Yes, within 25 items | Yes |
| Warranty reminders | Up to 3 | Unlimited |
| Insurance PDF and CSV | Preview, watermarked first page | Full |
| iCloud sync and backup | No | Yes |

Free users can always view, search and delete everything they entered (PRD §7).

### 1.5 iPad: windows, pointer and keyboard (D29)
- **Windows:** v1.0 shows one window. It resizes freely (Split View, Stage Manager, windowed apps); a narrow window gets the compact layout. **[v1.2 iPad]** Multiple windows.
- **Presentation on regular width:** editors (H-04, H-05, I-02), pickers (I-04, I-06), filters (F-05) and the paywall (P-01) open as centered form sheets. The Capture menu (C-01) opens as a popover anchored to the Capture button. Camera screens (C-02, C-06–C-08) stay full screen.
- **Capture button:** bottom trailing corner of the content column, never over the sidebar.
- **Pointer:** every tappable card and row has a hover effect (a highlight for rows, a lift for photo cards). Long-press menus also open with a secondary click.
- **Keyboard shortcuts** (they also show in the iPad menu bar; standard text editing and Esc to close a sheet come from the system):

| Shortcut | Action |
|---|---|
| ⌘1 – ⌘4 | Home, Find, Reports, Settings |
| ⌘F | Find (focuses the search field) |
| ⌘N | Add item (C-05) |
| ⇧⌘N | Scan room (C-02) |
| ⌘E | Edit the selected item or room |
| ⇧⌘M | Move the selected items (I-04). Not ⌘M, which iPadOS keeps for minimizing a window (D30) |
| ⌘⌫ | Delete the selected items (to Recently Deleted, with Undo) |
| ⌘Z / ⇧⌘Z | Undo / Redo the last move, delete or save |
| ⌘, | Nook's Settings tab. This replaces the system "Settings…" item, which would open the iPad Settings app (D30) |

- **[v1.2 iPad]** Drag and drop: items onto rooms, spots and containers (through `LocationService.move`, with Undo); photos and receipts from Files.

---

## 2. Screen inventory
| ID | Screen | Where | Presentation |
|---|---|---|---|
| L-01 | Launch | App start | Full screen |
| L-02 | App Lock | App start / return | Full-screen cover |
| O-01 | Welcome | First run | Full screen |
| O-02 | Pick your rooms | First run | Full screen |
| H-01 | Home | Home tab root | Tab root |
| H-02 | Room | Home → room card | Push (detail column on regular width) |
| H-03 | Spot / container | Room → spot | Push |
| H-04 | Room editor | Home / Room | Sheet |
| H-05 | Spot / container editor | Room / Spot | Sheet |
| H-06 | QR box label | Container | Sheet |
| H-07 | Arrange rooms | Home | Edit mode |
| I-01 | Item detail | Any item card | Zoom push from card |
| I-02 | Item editor | Add / Edit | Full-height sheet |
| I-03 | Photo viewer | Item / spot photo | Full screen |
| I-04 | Move picker | Move button | Medium sheet |
| I-05 | Location history | Item detail | Push |
| I-06 | Lend sheet | Item detail | Medium sheet |
| I-07 | Receipt viewer | Item detail | Quick Look |
| I-08 | Multi-select | Room / results | Edit mode |
| C-01 | Capture menu | Capture button | Small sheet |
| C-02 | Room scan camera | C-01 | Full screen |
| C-03 | Scan review (AI) | After C-02 | Full screen |
| C-04 | Manual tagging (Classic) | After C-02 | Full screen |
| C-05 | Quick add item | C-01 | Camera → I-02 |
| C-06 | Receipt scan | C-01 / item | Full screen |
| C-07 | Barcode scanner | C-01 / editor | Full screen |
| C-08 | Serial sticker reader | Item editor | Full screen |
| F-01 | Find | Find tab root | Tab root |
| F-02 | Results | Typing in F-01 | Inline |
| F-03 | Answer card | Question / result | Card in F-01 |
| F-04 | Move confirmation card | "I put X in Y" | Card in F-01 |
| F-05 | Filters | F-01 | Sheet |
| F-06 | Saved searches | F-01 | Inline section |
| R-01 | Reports | Reports tab root | Tab root |
| R-02 | Insurance report | R-01 | Push |
| R-03 | CSV export | R-01 | Sheet |
| R-04 | Warranties | R-01 | Push |
| R-05 | Lent out | R-01 | Push |
| S-01 | Settings | Settings tab root | Tab root |
| S-02 | Nook Pro | S-01 | Push |
| S-03 | iCloud sync | S-01 | Push |
| S-04 | Backup & restore | S-01 | Push |
| S-05 | Face ID / Touch ID lock | S-01 | Push |
| S-06 | Appearance | S-01 | Push |
| S-07 | Notifications | S-01 | Push |
| S-08 | Recently Deleted | S-01 | Push |
| S-09 | Privacy | S-01 | Push |
| S-10 | Tags | S-01 | Push |
| S-11 | Apple Intelligence | S-01 | Push |
| S-12 | Help & About | S-01 | Push |
| P-01 | Paywall | 26th item, Export, 4th reminder | Sheet |

---

## 3. Launch & lock

### L-01 Launch
- Warm canvas color with the Nook mark. Goes to L-02 if the lock is on, otherwise to O-01 on first run or the last-used tab.

### L-02 App Lock [PRD §5 F11, §9]
- **Elements:** opaque warm cover, app mark, "Unlock Nook" button.
- **Interactions:** Face ID on Face ID iPhones, Touch ID on iPhone SE and iPhone Duo (PRD §5 F11), invoked automatically on appear. Success cross-fades in with a success haptic; failure gives an error haptic plus a gentle color pulse, and the button stays available. The system falls back to the device passcode after repeated failures.
- **Always:** the app-switcher snapshot is covered while locked. [Inferred]
- **Private items** ask for authentication on open even when the app lock is off (PRD §9).

---

## 4. Onboarding (under 60 seconds, PRD §3)

### O-01 Welcome
- Illustration of a calm, organized shelf. Promise: **"Know what you own and where it is."** Button: Get Started.
- One line of privacy reassurance: "Everything stays on your iPhone. No account." [Inferred from PRD §1 principle 3]

### O-02 Pick your rooms
- Suggested chips: Kitchen, Living room, Bedroom, Garage, Office, Bathroom, and more. Tapping toggles a chip with a selection haptic. "+ Add your own" opens an inline text field.
- Each chosen room gets a soft color and SF Symbol automatically (PRD §3 visual system).
- Continue lands on Home (H-01) with empty room cards and a highlighted Capture button.
- **No permission prompts here.** Camera is requested only when the user first taps Scan (PRD §3 onboarding step 3).

### First guided scan
- The first time C-02 opens, the live **coach overlay** guides framing ("Step back a little so the whole shelf fits"). Target: first room documented in under 3 minutes, median (PRD §1 metrics).

---

## 5. Home tab

### H-01 Home [PRD §3 Navigation]
- **Header:** large rounded title (home name) [Inferred]. Total home value in SF Pro Rounded (masked when Hide values is on), with an eye button to toggle Hide values.
- **Content, top to bottom:**
  1. **Rooms** as large photo cards: cover photo or room color, SF Symbol, name, item count. Tap → H-02. "+ Room" card at the end.
  2. **Warranties ending soon:** horizontal cards with days left. Tap → I-01; "See all" → R-04.
  3. **Recently added:** photo cards. Tap → I-01.
- **Interactions:** long-press a room card → Rename, Change color and symbol, Arrange rooms (H-07), Delete. Long-press an item card → Open, Move, Lend, Mark Private, Delete.
- **[v1.1 Duo] Duo outer screen:** compact "Quick find" bar at the top plus 2 rows of cards; nothing important below the fold (PRD §4 rule 4).
- **Regular width:** sidebar shows rooms; the detail column shows the selected room's grid.
- **Empty:** illustration, "Let's start with one room.", button Scan a room.

### H-02 Room [PRD §3 pillar 1, §5 F1]
- Looks like a **well-lit shelf**: header in the room's color, with item count and room value.
- Items grouped by **spot**, each spot a section with its optional photo; containers appear as stacked "box" cards inside their spot.
- Photo grid: 2 columns compact, 3 on Pro Max landscape, 4–5 on regular width (PRD §4). Switches to a list at accessibility text sizes (PRD §3 accessibility).
- **Toolbar:** Scan this room, Add spot, Select (I-08), overflow: Edit room, Room report.
- **Interactions:** tap item → I-01 (zoom transition); tap spot header → H-03; drag to reorder spots [Inferred]: overflow → Arrange Spots, the same sheet as H-07.
- **Empty:** "Nothing here yet. Scan this room to fill it in 30 seconds." → Scan this room (PRD §3).

### H-03 Spot / container [PRD §5 F1, F8]
- Spot photo (tap → I-03), breadcrumb, items grid, nested containers (one level deep).
- Container extras: **Print or share QR label** (H-06) and a "Packed on" date for moving (PRD §6).
- **Toolbar:** Add item here, Move Container (containers only; carries everything inside, and each item's history records it, D44), Edit.

### H-04 Room editor
- Name, SF Symbol picker, soft color picker (room palette), the room's spots with "Add spot" (D28, for F1's 30-second target), optional cover photo, Delete room.
- **Delete with items** asks where they should go: choose another room or move them to Recently Deleted. [Inferred]
- Acceptance: create a room with 3 spots in under 30 seconds (PRD §5 F1).

### H-05 Spot / container editor
- Name, type (Spot or Container), parent (a spot can hold containers; containers nest one level), optional photo. Save / Cancel.

### H-06 QR box label [PRD §5 F8]
- Label preview: QR code, container name, room, and optionally the top items listed.
- Sizes for common label sheets plus a plain card. [Inferred]
- Actions: Print (AirPrint), Share, Save Image. Scanning the code with the system Camera app opens that container in Nook.

### H-07 Arrange rooms
- Edit mode with drag handles to reorder rooms. Done saves the order (`order` field, PRD §8).

---

## 6. Items

### I-01 Item detail [PRD §5 F2, §6]
- **Hero:** photo carousel (up to 10). Swipe between photos, tap for the viewer (I-03). Zoom transition from the source card (cross-fade under Reduce Motion, PRD §3).
- **Title block:** name, category, tags, Private badge, Lent badge.
- **Location card (most prominent):** breadcrumb, spot photo, "Last confirmed Aug 3", and two buttons: **Move** (I-04) and **"Found it here instead"** (also I-04). For valuables, an **Open Find My** link (PRD §6 honest limits).
- **Details card:** brand, model, serial (tap to copy), quantity, purchase date, price, store, value estimate (AI only, labeled "Estimate", PRD §5).
- **Warranty card:** end date, days left, reminder status ("Reminders 30 and 7 days before").
- **Receipt card:** thumbnail → I-07; "Add receipt" if missing.
- **Lending card:** "Jordan has it since Sep 12 · due Oct 1". Actions: Mark returned, Edit (I-06).
- **Notes**, then **Location history** row → I-05.
- **Toolbar:** Edit (I-02), Share, overflow: Lend, Mark Private, Duplicate [Inferred], Delete.
- **Phasing:** actions appear with their feature, never as dead ends: Move and "Found it here instead" (P4), Location history (P4), Lend and the lending card (P7), the warranty card (P7, D39), value estimate (P9), the locked state (P12).

### I-02 Item editor (add and edit) [PRD §5 F2]
- **Only Name is required.** An item with a photo and name saves in 2 taps (PRD §5 F2 acceptance).
- **Fields:** photos (up to 10), name (autocompletes from the 500 common items list and the user's past items), room and spot, category, tags, quantity, brand, model, serial (with "Read from sticker" → C-08), barcode (→ C-07), purchase date, price and currency, store, receipt (→ C-06 or Files), warranty length or end date (end computed from purchase date plus length, PRD §5 F4), notes, Private toggle.
- **AI prefill:** when created from a photo, the name, category, brand and condition are filled with a soft "Suggested" tint until edited or accepted (PRD §5).
- **Validation** inline under the field. A warranty end date before the purchase date shows a warning but doesn't block saving. [Inferred]
- Cancel with changes asks "Discard changes?". Save gives a success haptic, and the card settles into place.
- **At the 25-item free limit:** saving the 26th item opens P-01. The draft is kept and saves after purchase. [Inferred]

### I-03 Photo viewer
- Pinch and double-tap to zoom, swipe between photos, swipe down to dismiss. Actions: Set as cover, Share, Delete photo.

### I-04 Move picker [PRD §5 F6]
- **Last 5 used locations** at the top as one-tap rows, then rooms → spots → containers, with search.
  - Recents are the newest places moved to (adding an item counts) that still exist.
  - The item's current place is left out of the recents.
  - In the room list, the current place shows "Here now" and can't be picked (D44).
- Acceptance: **moving one item takes 2 taps** (Move → location).
- Works on one item or a multi-selection. Every move writes a LocationEvent (PRD §8). Confirmation toast with Undo, and a success haptic.
- **"Found it here instead"** opens the same picker titled "Where did you find it?" and records a `found` event (D44).
- **The same picker is used for:**
  - the item editor's Where row (it only fills the field, and Save moves)
  - Move Container on H-03 (no containers offered, D34)

### I-05 Location history [PRD §6]
- Timeline of moves: from → to, date, and source. Answers "Where did the drill used to be?".
- Source copy (D44): "Moved by you", "Found here by you", "Moved with Siri", "Suggested move, confirmed by you", "Moved by scanning a label". An item's first entry reads "Added".
- Paths are the names at the time of the move, so a deleted spot still reads in history.
- Reached from I-01's "Location history · N places" row, hidden until there's an entry.

### I-06 Lend sheet [PRD §5 F7]
- Person (system contact picker, or a typed name), date lent (default today), optional return date, optional reminder. Save adds the Lent badge and puts the item in the Lent out filter.

### I-07 Receipt viewer
- Quick Look for an image or PDF (D42). On Classic-scanned receipts, recognized text is selectable (P6).

### I-08 Multi-select
- Select in Room and in Find results. Bottom toolbar: Move, Tag, Mark Private, Delete. The count appears in the title.

---

## 7. Capture (floating button)

### C-01 Capture menu [PRD §3 Navigation]
- Four large tiles: **Scan room**, **Add item**, **Scan receipt**, **Scan barcode**. One tap each.
- Context-aware: opened from inside a room or spot, new items default to that location. [Inferred]

### C-02 Room scan camera [PRD §5 F3, §3]
- Live camera, coach overlay (first scan and when framing is poor), shutter, multi-photo counter, done button, current destination ("Saving to: Garage → Shelf").
- **[v1.1 Duo] iPhone Duo half-folded:** live camera on the top half, detected items on the bottom half, nothing over the hinge (PRD §4 rule 3).
- **First use:** a one-line soft ask, then the system camera prompt (PRD §3 onboarding). **If denied:** "Camera is off for Nook" with Open Settings, and the alternative "Pick from Photos".

### C-03 Scan review, AI path [PRD §5 F3, §3 motion]
- The photo shows each detected item with a **soft outline drawn one after another, each with a light haptic tap**, so detection feels alive.
- Cards stream in below (first card in under 2 s, PRD §9). Each card: crop, suggested name, category, condition, and controls **Accept / Edit / Remove**.
- Tapping an outline highlights its card and vice versa.
- **"Accept All"** in the header accepts every card at once (D28). **"Save all"** saves accepted cards to the current room and spot, then a success haptic and a summary toast: "6 items saved to Garage".
- **Fallbacks:** if the model is busy, a guardrail triggers, or 20 seconds pass, that photo silently switches to C-04 with the photo loaded (PRD §8 step 5).
- Acceptance: 8 clear items → at least 6 correct suggestions (PRD §5 F3).

### C-04 Manual tagging, Classic path [PRD §5 F3]
- The user **taps or draws a box** around an item, then types a name, with suggestions from the 500 common items list. Each tagged item appears as a card below.
- Same Accept / Edit / Remove and Save all as C-03, so both paths look alike.
- Acceptance: 8 items saved in under 2 minutes.

### C-05 Quick add item [PRD §5]
- Camera → photo → I-02. AI fills name, category, brand and condition; Classic leaves fields blank with autocomplete.
- Also offers "Choose from Photos" and "Skip photo".
- **P3 (D37):** the system camera stands in until P6. With the camera off or missing, I-02 opens directly and offers Photos.

### C-06 Receipt scan [PRD §5, F4]
- Document camera, or import a photo or PDF from Files or the share sheet. Share-sheet import needs a Share Extension or an "Open in Nook" document type. [Inferred]
- **AI:** store, date, price and warranty length are extracted into fields, each marked "Suggested", for review.
- **Classic:** Vision text recognition highlights prices and dates on the receipt; **the user taps a number to drop it into the focused field**.
- The receipt is attached to the item; extracted text is stored for search (PRD §8 Receipt.extractedText).

### C-07 Barcode scanner [PRD §5]
- System barcode scanner (UPC/EAN) on every iPhone. Reticle, guidance text, torch. A successful read gives a haptic and fills the barcode field. Manual entry is the fallback.

### C-08 Serial sticker reader [PRD §5]
- **AI:** the serial and model numbers are found and labeled on the sticker photo.
- **Classic:** all recognized lines are listed; the user taps the right line.

---

## 8. Find tab (headline feature, PRD §6)

### F-01 Find
- **One field** for both search and questions: placeholder "Search or ask: Where are the passports?".
- **Before typing:** "Try asking" with a question about the user's own latest item, saved searches (F-06), quick filters (Lent out, Warranty ending, Not seen in 2 years), and the last 5 searches. A quick filter with nothing behind it is hidden (D46).
- **AI iPhones:** questions are understood (item, room, time, action) and answered from the user's own database (PRD §6).
- **Every iPhone:** instant results with typo tolerance and synonyms ("fob" → "key").

### F-02 Results
- Instant results as you type, in under 100 ms for 5,000 items (PRD §5 F5).
- Sections: Items, Rooms and spots, Containers. Each item row shows a photo, name, breadcrumb, and a Move button.
- Private items show as "Private item" until the user unlocks with biometrics. [Inferred from PRD §6] Until P12 adds Face ID, tapping the row opens the item (D46).
- A footer says "Also searched receipts, serials and notes." Each item row's Move opens I-04; Select (I-08) works on results.
- **No results:** "Nothing called 'x' yet." with "Add 'x' as an item".

### F-03 Answer card [PRD §6]
- "**Office → Desk → Second drawer.** You put them there on Aug 3." Shows the item photo, spot photo, last confirmed date, and **Move** and **Found it here instead**.
- Variants: lent ("Jordan has it since Sep 12"); packed ("Box 14, packed Jun 2"); room contents ("What's in the garage?" → items grouped by spot); quantity ("Do I have AA batteries?" → "Yes, 2 packs in Kitchen → Drawer").
- Answers come only from saved data, so a location can never be invented (PRD §6).
- **Classic (P5, D46):** the card names the item and reads "Last confirmed Aug 3." under the place. Private items never answer. The lent card is read-only until P7 adds Mark Returned. On regular width the card sits beside the results.

### F-04 Move confirmation card [PRD §6]
- After typing or saying "I put the passports in the safe", on AI iPhones: "Move Passports to Bedroom → Safe?" with **Move** and **Not now**. **Nothing moves without that tap.**
- Classic: the sentence is treated as a search, and the user moves the item with the Move button.

### F-05 Filters [PRD §5 F5]
- Room, category, tag, value range, warranty status, lent out, last seen date (for decluttering, PRD §2). Active filters show as removable chips. "Save this search" → F-06.
- Value is in the home currency only (D41). Warranty and Lent out appear once there are warranties or loans to filter (D46). A form sheet on regular width (D45).

### F-06 Saved searches
- Named searches pinned on F-01. Rename, reorder and delete with swipe. [Inferred]

---

## 9. Reports tab

### R-01 Reports
- Cards: **Insurance report** (with item count and total value), **Export CSV**, **Warranties** (count ending soon), **Lent out** (count), and **Declutter** (items not seen in 2 years) [PRD §2].
- Pro badge on gated features.

### R-02 Insurance report (Pro) [PRD §5 F9]
- **Builder:** scope (whole home or chosen rooms), include photos, serials, receipt appendix, optional AI summary paragraph per room (AI iPhones only), and policy details for the cover [Inferred].
- **Preview:** page-by-page PDF grouped by room, with photos, values, serials, totals and receipts appended.
- **Free:** preview of a watermarked first page, with Unlock Pro → P-01 (PRD §7).
- **Generate:** progress ("Rendering 120 of 500 items"), under 20 s for 500 items on-device (PRD §9). Then the share sheet opens.

### R-03 CSV export (Pro)
- All fields, all items. Preview row count, then share or save to Files.

### R-04 Warranties [PRD §5 F4]
- Groups: Ending in 30 days, Active, Expired. Rows show photo, name, end date and days left.
- Tap → I-01. Swipe action: turn reminders on or off for that item.
- Free users with 3 active reminders see "Unlock Pro for unlimited reminders" when adding a 4th.

### R-05 Lent out [PRD §5 F7]
- Items, person, date lent, due date (overdue highlighted). Swipe: Mark returned.

---

## 10. Settings tab
| ID | Screen | Contents |
|---|---|---|
| S-01 | Settings root | Pro status card (or Unlock), sync, backup, lock, appearance, notifications, Recently Deleted, tags, Apple Intelligence, privacy, help |
| S-02 | Nook Pro | What's included, Restore Purchases, Family Sharing note (PRD §7) |
| S-03 | iCloud sync (Pro) | Toggle, last synced, status (signed out, storage full), "Sync now" [Inferred] |
| S-04 | Backup & restore | Create a .nookbackup file (zip of JSON and photos, PRD §5 F9); restore by replacing or merging, with confirmation [Inferred] |
| S-05 | Lock | Face ID / Touch ID toggle, lock timing [Inferred]; note that Private items always require it |
| S-06 | Appearance | System / Light / Dark; **accent color, 6 options** (PRD §3); Hide values by default [Inferred] |
| S-07 | Notifications | Warranty reminders (30 and 7 days, PRD §5 F4), loan reminders; if denied, a "Turn on in Settings" row |
| S-08 | Recently Deleted | Items with days left out of 30; Restore or Delete Now; Delete All with confirmation |
| S-09 | Privacy | Plain-language privacy page (PRD §9): what stays on the device, what iCloud sync does, "Data Not Collected" |
| S-10 | Tags | Rename, merge, delete. Categories are a fixed list of 10 (PRD §8 DetectedItem) |
| S-11 | Apple Intelligence | Status: Ready, Downloading, Not available on this iPhone, or Turned off. App-level "Use Apple Intelligence" toggle [Inferred from PRD §8 "AI turned off"] |
| S-12 | Help & About | How-to tips, contact, version, acknowledgements |

---

## 11. Paywall

### P-01 Paywall [PRD §7]
- **Triggers:** saving the 26th item, tapping Export on the insurance report or CSV, or adding a 4th warranty reminder. **Never on launch.**
- **One screen, one price, one button.** Shows the user's own numbers: "You've documented 25 items worth $4,380."
- Native StoreKit `ProductView`, Restore Purchases, terms and privacy links, a close button that's always visible.
- **States:** loading price; purchasing; pending (Ask to Buy); success (confetti-free warm "settle", success haptic, then return to the interrupted action); failed or cancelled (stay on screen, no blame).
- Launch pricing: $14.99 introductory for 2 weeks, then $19.99 (PRD §7).

---

## 12. System surfaces
| Surface | Behavior | Source |
|---|---|---|
| Widgets | "Warranties ending soon", "Total home value" (respects Hide values) [Inferred], "Quick find" (opens Find). Excludes Private items. | [PRD §5 F10, §9] |
| Control Center control | Opens room scan | [PRD §5 F10] |
| Action button | Option to launch room scan | [PRD §8] |
| Lock Screen control | Quick Move / Find | [PRD §6, §10 risks] |
| Siri & Shortcuts | `FindItemIntent`, `MoveItemIntent`, `ListRoomIntent`, `AddItemIntent`, `ScanRoomIntent` | [PRD §8] |
| Spotlight | Items and rooms indexed, except Private items | [PRD §8, §9] |
| QR codes | System Camera opens the container | [PRD §5 F8] |
| Notifications | Warranty: "Your dishwasher warranty ends in 30 days" (View, Snooze [Inferred]); loan due: "Jordan's had your drill for 3 weeks" | [PRD §5 F4, F7] |
| Share sheet in | Receipts (image or PDF) from other apps | [PRD §5 F4] |

---

## 13. Permissions (always just-in-time)
| Permission | Asked when | If denied |
|---|---|---|
| Camera | First tap on Scan or Add item photo (PRD §3) | Choose from Photos, plus "Turn on camera in Settings" |
| Photos | Never: the system photo picker needs no permission | n/a |
| Notifications | First time the user saves a warranty or a loan reminder [Inferred] | Inline "Reminders are off" row → Settings |
| Contacts | Never: the system contact picker shares only the chosen contact [Inferred] | n/a |
| Face ID | Turning on the lock, or first opening a Private item | Device passcode |

---

## 14. Adaptive layouts per key screen (PRD §4)
### v1.0 layouts
| Screen | Compact | Regular width | Accessibility text sizes |
|---|---|---|---|
| Home | Stacked sections, 2-column cards | Sidebar rooms + room grid | Cards become a list |
| Room | 2-column grid (3 on Pro Max landscape) | 4–5 columns, item detail beside grid | List |
| Item detail | Photo above details | Opens beside grid | Single column, larger text |
| Room scan | Full camera, cards in a bottom sheet | Camera left, cards right [Inferred] | Cards as a list |
| Find | Field + results | Results with answer card beside [Inferred] | Rows stack vertically |
| Editors, settings, reports | Full width | Form sheet or readable-width column, never stretched (D29) | Single column |

v1.0 rules: layout depends on size classes only, never on device model (PRD §4); each safe-area edge is handled separately; the app works at any Split View width and any resized iPad window. On iPad, the same split view shows sidebar, grid and item detail together when the window is wide enough; the system hides the sidebar in narrower windows (D29). Apps built with Xcode 27 can't opt out of resizing, so these regular-width layouts are what Duo owners see on the inner screen in v1.0.

### [v1.1 Duo] layouts
| Screen | Duo outer | Duo half-folded |
|---|---|---|
| Home | Quick find bar + 2 rows | Not special |
| Room | 2 columns, short header | Not special |
| Item detail | Photo shorter, details scroll | Photo above fold, details below |
| Room scan | Camera with short card tray | Camera top, items bottom |
| Find | Field pinned, 2 rows visible | Not special |

v1.1 rules: nothing sits on the hinge (`ReservedRegion`, iOS 27.1 SDK); content reaches the inner screen's edges; the app keeps its place when the Duo opens or closes.

---

## 15. Edge cases checklist
- Long names (wrap to 2 lines), long serials (middle truncation, full on tap to copy).
- Items with 0 or 10 photos; receipts as large PDFs.
- Nesting limit: a container inside a container is the maximum (PRD §5 F1); the UI prevents deeper nesting.
- Deleting a room or spot that has items, or a container that's in a move history.
- Warranty already expired when entered; purchase date in the future.
- Free limit reached mid room scan: accepted cards beyond 25 items stay in review until the user unlocks or removes some. [Inferred]
- AI mid-download, busy, or refusing (guardrail): silent Classic fallback.
- More warranty reminders than iOS allows to be scheduled at once (64 pending): the app schedules the soonest and reschedules as reminders fire. [Inferred technical note]
- Time zones and DST for reminder times.
- iCloud signed out, storage full, or sync conflicts (Pro).
- Restore from backup onto a device that already has data.
- VoiceOver, Voice Control, largest text size, Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, and every Liquid Glass transparency setting.
- **[v1.1 Duo]** iPhone Duo: opening or closing mid-flow, rotating, Split View on either side.
- iPad: resizing the window mid-flow (regular ↔ compact), rotating, a hardware keyboard attached or removed, pointer-only use, an iPad without Apple Intelligence (D29).

---

## 16. Items marked [Inferred]
All closed in P0 by **D26** (Capture placement) and **D28** (everything else). The `[Inferred]` tags above are kept as history; the canvas in `design/screens/` shows the settled design.

> The PRD's two embedded diagrams ("Roadmap · 4 phases, 4 gates" and "App architecture · 6 layers") appear only as placeholders in the attached file, so they weren't available for this review.
