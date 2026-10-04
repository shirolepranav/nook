# Nook Design System — "Warm Home"

**Source:** *Home Inventory & Warranty Vault — PRD + Technical Spec* (Sep 27, 2026), mainly PRD §3 (Design and UX principles) and §4 (Device and screen support).
**Direction:** warm and tactile, soft materials, friendly. In the PRD's words, every screen should feel like a first-party Apple app, only warmer: calm, tactile and personal, "a well-organized home, not a spreadsheet".
**Modes:** full light and dark mode, plus tinted app icon support (PRD §3).

> Color values below are starting points chosen to meet the PRD's 4.5:1 text contrast. Verify every pair with Xcode's Accessibility Inspector before shipping.

---

## 1. Principles
These follow the PRD's design pillars (§3), with one rule added for the warm-and-tactile direction.

1. **Photos are the interface.** Items are large photo cards, not rows of text. A room looks like a well-lit shelf.
2. **One obvious action per screen.** Capture is always one tap away on the floating Liquid Glass button.
3. **Native, not generic.** System components with the iOS 27 Liquid Glass look for tab bar, toolbars and sheets. Custom styling is limited to cards, colors and illustrations. There's no opt-out from Liquid Glass in iOS 27, so we design with it.
4. **Kind to mistakes.** AI results are suggestions; everything is editable and undoable; deletes last 30 days in Recently Deleted.
5. **Quiet by default.** No badges, streaks or nagging. Notifications only for warranties and loans the user asked about.
6. **Paper for content, glass for controls.** *(Added for this direction.)* Cards, photos and forms sit on opaque, warm "paper" surfaces. Liquid Glass is only for the system chrome and the Capture button. This keeps content readable at every Liquid Glass transparency setting and with Reduce Transparency on.

---

## 2. Color

### 2.1 Neutrals and surfaces
Warm neutral backgrounds (PRD §3). Dark mode uses warm espresso tones, never pure black, and warm off-white text, never pure white.

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F7F3EE` | `#1B1714` | App background |
| `surface` | `#FFFDFA` | `#25201C` | Cards, rows, sheets' custom content |
| `surfaceRaised` | `#FFFFFF` | `#2E2823` | Toasts, answer cards, popovers |
| `surfaceSunken` | `#EFE8DF` | `#141110` | Text-field wells, photo placeholders |
| `hairline` | `#E4DACE` | `#3A322B` | Card borders, dividers |
| `textPrimary` | `#2A2420` | `#F3ECE3` | Titles and body |
| `textSecondary` | `#6A5E55` | `#BEB2A6` | Breadcrumbs, metadata |
| `textTertiary` | `#8A7E75` | `#8E8379` | Placeholders only, never essential information |

### 2.2 Accent colors (user picks 1 of 6, PRD §3)
The chosen accent tints buttons, selection, links, the Capture button and system controls. Each has its own color for text drawn on top of it (`onAccent`).

| Accent | Light | Dark | `onAccent` light / dark | Feel |
|---|---|---|---|---|
| **Terracotta** (default) | `#B4502C` | `#EA8B64` | white / `#1B1714` | Warm clay |
| Sage | `#4F7A57` | `#94BC9B` | white / `#1B1714` | Calm garden |
| Ocean | `#2F6A8F` | `#8CBFE0` | white / `#1B1714` | Quiet blue |
| Plum | `#8A4A78` | `#D9A0C8` | white / `#1B1714` | Soft berry |
| Honey | `#9A6210` | `#E8B04F` | white / `#1B1714` | Golden wood |
| Graphite | `#4A4F57` | `#B9BEC6` | white / `#1B1714` | Neutral, minimal |

Rules:
- In dark mode accents get lighter, and text on accent fills becomes dark.
- Semantic colors (below) never change with the accent, so "expired" always looks the same.

### 2.3 Room colors (PRD §3)
Every room gets a soft color and an SF Symbol, used on cards, widgets and the map of the home. The **fill** is a soft tint for card backgrounds; the **ink** is a stronger shade for the symbol on that fill.

| Room color | Fill light | Fill dark | Ink light | Ink dark |
|---|---|---|---|---|
| Clay | `#F1DDD3` | `#4A3329` | `#9A4527` | `#F0B59A` |
| Sage | `#DCE7DA` | `#2F3D31` | `#3F6B48` | `#A9CBAE` |
| Sky | `#D8E6F0` | `#2B3A46` | `#2E6488` | `#A6CBE6` |
| Lavender | `#E5DDEE` | `#3A3245` | `#66508A` | `#C8B6E2` |
| Butter | `#F4E9C9` | `#463C22` | `#7E5F12` | `#E9CF86` |
| Rose | `#F2DADF` | `#47303A` | `#9A3F57` | `#EDB0C0` |
| Stone | `#E6E1DA` | `#3B3631` | `#5E554C` | `#CFC6BC` |
| Mint | `#D6ECE5` | `#2A4039` | `#2F7360` | `#A3D6C6` |

### 2.4 Semantic colors
Status is never shown by color alone: always icon plus text ("Ends in 12 days").

| Token | Light | Dark | Use |
|---|---|---|---|
| `success` | `#3D7A4C` | `#7FC08C` | Saved, warranty active |
| `warning` | `#A4610E` | `#E7AE52` | Warranty ending within 30 days, loan due soon |
| `danger` | `#B3261E` | `#F28B80` | Expired, overdue, delete |
| `info` | `#3A6889` | `#8FB8D6` | Tips, sync status |
| `suggested` | accent at 12% opacity | accent at 18% opacity | Background of AI-filled fields until accepted |

### 2.5 Implementing colors
Each token is a Color Set in the asset catalog with Any, Dark, and High Contrast variants.

```swift
import SwiftUI

// MARK: - Neutral color tokens
// Each name matches a Color Set in Assets.xcassets.
// The Color Set holds Light, Dark and High Contrast versions,
// so SwiftUI picks the right one automatically.
enum NookColor {
    static let canvas        = Color("canvas")         // app background
    static let surface       = Color("surface")        // cards and rows
    static let surfaceRaised = Color("surfaceRaised")  // toasts, answer cards
    static let surfaceSunken = Color("surfaceSunken")  // text-field wells
    static let hairline      = Color("hairline")       // thin borders
    static let textPrimary   = Color("textPrimary")    // main text
    static let textSecondary = Color("textSecondary")  // supporting text
    static let success       = Color("success")
    static let warning       = Color("warning")
    static let danger        = Color("danger")
}

// MARK: - User-selectable accent (6 options, PRD §3)
// Asset catalog folders "Accent" and "OnAccent" must have
// "Provides Namespace" ticked so names like "Accent/sage" work.
enum AccentChoice: String, CaseIterable, Identifiable {
    case terracotta, sage, ocean, plum, honey, graphite

    var id: String { rawValue }

    // The accent itself (buttons, selection, Capture button).
    var color: Color { Color("Accent/\(rawValue)") }

    // Color for text or icons placed ON the accent.
    var onAccent: Color { Color("OnAccent/\(rawValue)") }
}

// MARK: - Applying the accent app-wide
@main
struct NookApp: App {
    // Remembers the user's choice between launches. Default is terracotta.
    @AppStorage("accentChoice") private var accent: AccentChoice = .terracotta

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(accent.color) // tints buttons, toggles, tab bar selection and glass controls
        }
    }
}
```

---

## 3. Typography
SF Pro with Dynamic Type everywhere; **SF Pro Rounded for large headings and totals** (PRD §3). Body text stays in SF Pro for readability. Prices and counts use monospaced digits so numbers don't shift as they change.

| Token | Text style | Default size | Weight | Design | Use |
|---|---|---|---|---|---|
| `display` | `.largeTitle` | 34 | Bold | Rounded | Tab titles, home name |
| `total` | `.largeTitle` | 34 | Semibold | Rounded, mono digits | Total home value |
| `title` | `.title2` | 22 | Semibold | Rounded | Item and room headers |
| `section` | `.title3` | 20 | Semibold | Rounded | Section and card titles |
| `headline` | `.headline` | 17 | Semibold | Default | Card item names |
| `body` | `.body` | 17 | Regular | Default | Body text, fields |
| `meta` | `.subheadline` | 15 | Regular | Default | Breadcrumbs, last confirmed |
| `footnote` | `.footnote` | 13 | Regular | Default | Helper text |
| `caption` | `.caption` | 12 | Medium | Default | Chips, badges |
| `value` | `.title3` | 20 | Semibold | Rounded, mono digits | Prices on detail screens |

Dynamic Type rules (PRD §3 accessibility):
- Support every size up to the largest accessibility size.
- At accessibility sizes, photo grids become lists and side-by-side rows stack vertically.
- Wrap text instead of truncating anything essential; long serials truncate in the middle and show in full on tap.
- Never put text inside images.

```swift
// MARK: - Typography tokens
// Text styles (like .body) grow and shrink with the user's text size setting.
extension Font {
    static let nookDisplay  = Font.largeTitle.weight(.bold)
    static let nookTitle    = Font.title2.weight(.semibold)
    static let nookSection  = Font.title3.weight(.semibold)
    static let nookHeadline = Font.headline
    static let nookBody     = Font.body
    static let nookMeta     = Font.subheadline
}

// MARK: - Money text (totals and prices)
struct MoneyText: View {
    let amount: Decimal
    let currencyCode: String
    var font: Font = .title3.weight(.semibold)

    // When "Hide values" is on, prices show as dots (PRD §5 F11).
    @AppStorage("hideValues") private var hideValues = false

    var body: some View {
        Group {
            if hideValues {
                Text("••••")
                    .accessibilityLabel("Value hidden")       // VoiceOver doesn't read the dots
            } else {
                Text(amount, format: .currency(code: currencyCode))
            }
        }
        .font(font)
        .fontDesign(.rounded)   // soft, friendly numerals (PRD §3)
        .monospacedDigit()      // every digit the same width, so totals don't wiggle
    }
}
```

---

## 4. Spacing and layout
**8-pt spacing grid** (PRD §3), with 4 pt allowed only for tight gaps inside a component.

| Token | Value | Use |
|---|---|---|
| `half` | 4 | Icon to label inside a chip |
| `s1` | 8 | Between related lines of text |
| `s2` | 16 | Card padding, screen side margins on compact width |
| `s3` | 24 | Between sections |
| `s4` | 32 | Above major headers |
| `s5` | 40 | Empty-state spacing |
| `s6` | 48 | Large hero spacing |

Layout rules (PRD §4):
- Layouts depend on **size classes only**, never on device model, screen size or orientation.
- Photo grid columns: 2 on compact width, 3 on Pro Max landscape, 4–5 on regular width.
- Handle each safe-area edge separately (bars can sit on the left or right in some layouts).
- **v1.1 (iPhone Duo):** nothing on the hinge; use `ReservedRegion`, which needs the iOS 27.1 SDK.
- Never use `UIScreen.main`; read size and scale from the environment or window scene.
- Tap targets are at least 44 × 44 pt, with at least 8 pt between targets.

```swift
// MARK: - Spacing tokens (8-pt grid)
enum Space {
    static let half: CGFloat = 4    // only for tight gaps inside a component
    static let s1: CGFloat = 8
    static let s2: CGFloat = 16
    static let s3: CGFloat = 24
    static let s4: CGFloat = 32
}

// MARK: - Photo grid that adapts to width and text size
struct ItemGrid: View {
    let items: [ItemSummary]
    @Environment(\.horizontalSizeClass) private var sizeClass   // compact or regular width
    @Environment(\.dynamicTypeSize) private var typeSize        // user's text size

    var body: some View {
        if typeSize.isAccessibilitySize {
            // Very large text: a list reads better than a grid (PRD §3).
            LazyVStack(spacing: Space.s1) {
                ForEach(items) { ItemRow(item: $0) }
            }
        } else {
            // More columns when there's more room (PRD §4).
            let columnCount = sizeClass == .regular ? 4 : 2
            let columns = Array(repeating: GridItem(.flexible(), spacing: Space.s2), count: columnCount)
            LazyVGrid(columns: columns, spacing: Space.s2) {
                ForEach(items) { ItemPhotoCard(item: $0) }
            }
        }
    }
}
```

---

## 5. Shape and corners
**Concentric corner radii that follow the device's screen corners** (PRD §3). Inner corners equal the outer radius minus the padding between them, so nested shapes look like they belong together. Use `ConcentricRectangle` so cards also follow each screen's corner shape, including iPhone Duo's (PRD §4 rule 7).

| Token | Radius | Use |
|---|---|---|
| `capsule` | Full | Buttons, chips, pills, search field |
| `small` | 8 | Badges, tiny thumbnails |
| `medium` | 12 | Text fields, list thumbnails |
| `card` | 24 | Photo cards, room cards (outer) |
| `hero` | 32 | Answer card, onboarding panels |
| `concentric` | Computed | Photos inside cards, cards near screen edges |

All rounded rectangles use the continuous corner style (the smooth "squircle" Apple uses).

```swift
// MARK: - Photo card with concentric corners
struct ItemPhotoCard: View {
    let item: ItemSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            // A 4:5 frame that the photo fills; the photo is clipped
            // to a corner radius computed from the card's own corners.
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay {
                    item.thumbnail
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(ConcentricRectangle())   // inner radius = card radius − padding

            Text(item.name)
                .font(.nookHeadline)
                .foregroundStyle(NookColor.textPrimary)
                .lineLimit(2)

            Text(item.locationText)                  // e.g. "Kitchen → Top shelf"
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .lineLimit(1)
        }
        .padding(Space.s1)
        // Opaque warm "paper" surface, never glass (principle 6).
        .background(NookColor.surface, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(NookColor.hairline, lineWidth: 1)   // crisp edge, important in dark mode
        }
        // Tells ConcentricRectangle inside what the outer shape is.
        .containerShape(.rect(cornerRadius: 24, style: .continuous))
        .warmShadow()
        // VoiceOver reads the card as one element with name, room and value (PRD §3).
        .accessibilityElement(children: .combine)
    }
}
```

---

## 6. Materials, elevation and texture

### 6.1 Three layers
| Layer | Material | Examples |
|---|---|---|
| Canvas | Flat warm linen | App background |
| Content | Opaque paper with warm shadow (light) or lighter surface plus hairline (dark) | Photo cards, room cards, forms, answer cards |
| Controls | System Liquid Glass, tinted with the accent | Tab bar, toolbars, sheets, Capture button, camera controls |

### 6.2 Elevation
| Level | Light mode (shadow in warm brown, not black) | Dark mode |
|---|---|---|
| Flat | None | None |
| Low (cards) | 2 pt down, 8 pt blur, 6% + 1 pt down, 2 pt blur, 4% | `surface` + hairline |
| Lifted (pressed or dragging) | 8 pt down, 20 pt blur, 10% | `surfaceRaised` + hairline |
| Floating (toasts, answer card) | 16 pt down, 32 pt blur, 14% | `surfaceRaised` + lighter border |

### 6.3 Liquid Glass rules
- Use native bars and sheets; tint with the accent rather than adding backgrounds.
- Custom glass only for the Capture button and floating camera controls (`.glass` / `.glassProminent` button styles).
- Never put glass on cards, photos or rows, and never stack glass on glass.
- Test at both ends of the iOS 27 Liquid Glass transparency setting, and with Reduce Transparency and Increase Contrast.

### 6.4 Tactile texture
- An optional, very faint paper grain (2–3% opacity) on `canvas` only, to make the background feel like a material rather than a flat color.
- Removed automatically when Increase Contrast or Reduce Transparency is on.
- Never on photos, text or glass.

```swift
// MARK: - Warm shadow
// Brown-tinted shadows feel softer on warm backgrounds than black ones.
extension View {
    func warmShadow(lifted: Bool = false) -> some View {
        modifier(WarmShadow(lifted: lifted))
    }
}

struct WarmShadow: ViewModifier {
    var lifted: Bool
    @Environment(\.colorScheme) private var scheme
    private let brown = Color(red: 0.35, green: 0.23, blue: 0.13)

    func body(content: Content) -> some View {
        if scheme == .dark {
            // Shadows barely show in dark mode; lighter surfaces and borders do the work.
            content
        } else if lifted {
            content.shadow(color: brown.opacity(0.10), radius: 20, y: 8)   // picked up
        } else {
            content
                .shadow(color: brown.opacity(0.06), radius: 8, y: 2)       // soft spread
                .shadow(color: brown.opacity(0.04), radius: 2, y: 1)       // tight contact
        }
    }
}
```

---

## 7. Iconography and illustration
- **SF Symbols 7 only**, with variable color and symbol effects (PRD §3). Hierarchical rendering by default; room symbols use the room's ink color.
- Symbol weight matches nearby text.
- Symbol effects with meaning only: a checkmark that draws on when saving, variable color for progress (report rendering, scan progress).
- **Illustrations** for empty, loading and error states (PRD §3): soft, rounded, hand-made feeling (gouache or clay look) in the warm palette, with the user's accent as the highlight color. They're decorative, so VoiceOver skips them.
- **App icon:** light, dark, clear and tinted variants built in Icon Composer (PRD §3).

Suggested symbols:

| Concept | Symbol |
|---|---|
| Home tab | `house` |
| Find tab | system search tab |
| Reports tab | `doc.text` |
| Settings tab | `gearshape` |
| Capture | `camera.viewfinder` |
| Scan room | `viewfinder` |
| Receipt | `receipt` |
| Barcode | `barcode.viewfinder` |
| Move | `arrow.up.and.down.and.arrow.left.and.right` |
| Warranty | `checkmark.shield` |
| Lent | `person.crop.circle.badge.clock` |
| Private | `lock.fill` |
| Container | `shippingbox` |

---

## 8. Components

### 8.1 Capture button (floating, PRD §3 pillar 2)
- 56 pt circle, Liquid Glass prominent style tinted with the accent, `camera.viewfinder` symbol.
- Bottom trailing, above the tab bar, inside the safe area. Hidden on capture screens, the paywall and the lock screen.
- Tap: opens the Capture menu with a light haptic. Long-press: jumps straight to Scan room. [Proposed]

```swift
// MARK: - Floating Capture button
struct CaptureButton: View {
    @Binding var showCaptureMenu: Bool

    var body: some View {
        Button {
            showCaptureMenu = true                      // opens the Capture menu (C-01)
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)            // well above the 44 pt minimum
        }
        .buttonStyle(.glassProminent)                    // Liquid Glass, tinted by the app's accent
        .buttonBorderShape(.circle)
        .accessibilityLabel("Capture")
        .accessibilityHint("Scan a room, add an item, or scan a receipt or barcode")
        .sensoryFeedback(.impact(weight: .light), trigger: showCaptureMenu)
    }
}

// Usage: add it to each tab's content so it sits above the tab bar.
// SomeTabContent()
//     .overlay(alignment: .bottomTrailing) {
//         CaptureButton(showCaptureMenu: $showCapture).padding(Space.s2)
//     }
```

### 8.2 Buttons
| Variant | Look | Use |
|---|---|---|
| Primary | Capsule, accent fill, `onAccent` label, 50 pt tall | One per screen: Save, Save all, Unlock Pro |
| Secondary | Capsule, accent at 12% fill, accent label | Alternatives: Edit, Add spot |
| Tertiary | Text in accent | Cancel-like actions, links |
| Destructive | Danger-colored label | Delete |
| Glass | System glass styles | Floating controls only |

States: pressed (shrinks to 97% with a soft spring); disabled (40% opacity, no haptic); loading (spinner replaces the label, width stays the same).

### 8.3 Cards
- **Item photo card:** 4:5 photo, name (2 lines), breadcrumb; badges in the top corner for Private, Lent, warranty ending. Pressed: lifts and shrinks to 98%.
- **Room card:** room color fill, SF Symbol in room ink, cover photo if set, name, item count. Shelf-like proportions (wider than tall).
- **Answer card (Find):** `surfaceRaised`, hero radius, breadcrumb in `section` type, item photo and spot photo side by side, "Last confirmed" line, Move and "Found it here instead" buttons.
- **Move confirmation card:** like the answer card, with the proposed location in bold and Move / Not now. Nothing moves without a tap (PRD §6).
- **Warranty card:** days left with a small progress ring in the semantic color, plus text ("Ends in 12 days").

### 8.4 Location breadcrumb
- "Bedroom → Wardrobe → Top shelf" in `meta` type, the room segment in its room ink color.
- Each segment is tappable; VoiceOver reads it as "Bedroom, Wardrobe, Top shelf".
- Wraps onto 2 lines at large text sizes instead of truncating.

### 8.5 Detection outline (room scan)
- Soft rounded outline in the accent at 80% opacity, 2 pt, with a faint glow in light mode.
- Outlines appear one after another with a light haptic tap each (PRD §3 motion).
- Selected outline: thicker and filled at 15% opacity; its card highlights below.
- Under Reduce Motion, outlines fade in without the draw animation; haptics remain.

```swift
// MARK: - Detected items appear one by one, each with a light tap
struct DetectionOverlay: View {
    let boxes: [CGRect]                    // item boxes from the scan, in view coordinates
    @State private var visibleCount = 0    // how many outlines are showing so far
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(boxes.prefix(visibleCount).enumerated()), id: \.offset) { _, box in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.tint.opacity(0.8), lineWidth: 2)   // uses the app's accent
                    .frame(width: box.width, height: box.height)
                    .offset(x: box.minX, y: box.minY)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
            }
        }
        // A light haptic each time a new outline appears (PRD §3).
        .sensoryFeedback(.impact(weight: .light), trigger: visibleCount)
        .task {
            // Reveal outlines one after another so detection feels alive.
            for index in boxes.indices {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    visibleCount = index + 1
                }
            }
        }
        .accessibilityHidden(true)   // the item cards below carry the VoiceOver information
    }
}
```

### 8.6 Inputs
- Text field: `surfaceSunken` well, medium radius, at least 48 pt tall, label above, helper or error text below.
- Focus: 2 pt accent border. Error: danger border, icon and message (never color alone).
- **AI-suggested fields:** `suggested` background tint and a small "Suggested" label until the user edits or accepts.
- Special fields: name with autocomplete; currency with the locale's decimal keypad; compact date picker; serial in monospaced type with "Read from sticker"; tags as tokens; photo strip with add, reorder and delete.

### 8.7 Chips, pills and badges
- Filter chip: 32 pt capsule with a 44 pt hit area; selected uses accent at 12% fill plus a checkmark.
- Room chip (onboarding): room color fill, symbol, name.
- Status pills: Active (success), Ending soon (warning), Expired (danger), Lent (info), always icon plus text.
- Badges on cards: small glyphs only (lock, person, clock), each with an accessibility label.

### 8.8 Navigation, sheets and dialogs
- Tab bar: system Liquid Glass, tinted by the accent, no custom background. Becomes a sidebar on regular width (PRD §4).
- Large rounded titles on tab roots; inline titles on detail screens. The primary action sits at the trailing end of the toolbar.
- Sheets: system sheets with a grabber; medium height for pickers (Move, Lend), large for editors. Custom content inside sheets stays on opaque surfaces.
- Confirmation dialogs name the action clearly ("Delete 3 items"). Remind users that deletes can be undone for 30 days.

### 8.9 Empty, loading, error and success states
Each state is a designed screen: **illustration, one sentence, one action** (PRD §3).

| State | Design |
|---|---|
| Empty | 140–180 pt illustration, `section` title, one sentence, primary button. Example: "Nothing here yet. Scan this room to fill it in 30 seconds." |
| Loading | Skeleton photo cards in `surfaceSunken` with a slow warm shimmer (static under Reduce Motion) |
| Error | Calm icon, plain reason, reassurance ("Your items are safe on this iPhone"), Retry |
| Success | Toast at the bottom on `surfaceRaised`: icon, message, Undo; 4 seconds; announced to VoiceOver |
| AI fallback | No visible state: the Classic screen appears with the photo already loaded |

### 8.10 Paywall (PRD §7)
- One screen, one price, one button. Warm illustration of a full shelf, the user's own numbers ("You've documented 25 items worth $4,380") in `total` type, three short benefit lines, the native StoreKit product view, Restore Purchases, and a close button that's always visible.
- No countdown timers, fake discounts or guilt. On success: a warm settle animation and a success haptic, then straight back to what the user was doing.

---

## 9. Motion (PRD §3)
| Moment | Motion | Reduce Motion version |
|---|---|---|
| Photo card → item detail | Zoom transition from the card | Cross-fade (PRD §3) |
| Item saved | Card settles into the grid with a soft spring and success haptic | Fade in |
| AI detection | Outlines appear one by one with light taps | Fade in; haptics stay |
| Button press | Shrinks to 97%, springs back | No scale; opacity change |
| Filters change | Smooth cross-fade of results | Same |
| Move confirmed | Item card slides toward the new location chip | Fade |

Rules: motion explains cause and effect; nothing longer than 0.6 seconds; only loading shimmer loops.

```swift
// MARK: - Zoom into item detail, cross-fade when Reduce Motion is on
struct ItemLink: View {
    let item: ItemSummary
    let namespace: Namespace.ID            // shared between the grid and the detail screen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationLink {
            if reduceMotion {
                ItemDetailView(item: item)  // standard transition (PRD §3: cross-fade, not zoom)
            } else {
                ItemDetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: namespace)) // grows from the card
            }
        } label: {
            ItemPhotoCard(item: item)
                .matchedTransitionSource(id: item.id, in: namespace)   // where the zoom starts
        }
        .buttonStyle(.plain)
    }
}
```

---

## 10. Haptics (PRD §3)
| Event | Feedback |
|---|---|
| Item or items saved, purchase complete, unlock success | Success |
| Picker or chip selection, segment change | Selection |
| Each detected item outline appearing | Light impact |
| Barcode or QR recognized, photo taken | Light impact |
| Move confirmed | Success |
| Unlock failed, validation error | Error |

Haptics never carry meaning alone; every event also has a visual change.

```swift
// MARK: - Success haptic only when saving actually worked
struct SaveItemButton: View {
    var save: () -> Bool                  // returns true when the item saved
    @State private var savedCount = 0     // changing this number plays the haptic

    var body: some View {
        Button("Save") {
            if save() { savedCount += 1 }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .sensoryFeedback(.success, trigger: savedCount)
    }
}
```

---

## 11. Accessibility (release requirement, PRD §3)
- **VoiceOver:** every card has a label with item name, room and value ("Coffee machine, Kitchen, Top shelf, 249 dollars"); Hide values reads as "Value hidden". Swipe and context-menu actions are also available as accessibility actions. Section headers are marked as headings. Toasts are announced.
- **Dynamic Type** up to the largest accessibility size; grids switch to lists.
- **Contrast:** at least 4.5:1 for text and 3:1 for large text and essential icons, in light, dark and Increase Contrast, at every Liquid Glass transparency setting.
- **Tap targets** at least 44 × 44 pt.
- **No camera, no AI required:** every action works with manual entry and Photos (PRD §3).
- **Respect system settings:** Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, Button Shapes, Smart Invert (photos are excluded from inversion).
- **Voice Control:** accessibility labels match the visible text.
- **App Store Accessibility Nutrition Label** filled in honestly (PRD §3).

---

## 12. Adaptive design (PRD §4)
| Context | Design response |
|---|---|
| iPhone SE (4.7") | Smallest test device; 2-column grid; Touch ID lock; no Dynamic Island assumptions |
| Standard and Pro Max | 2 columns; 3 on Pro Max landscape; regular width in Pro Max landscape gets the sidebar |
| Regular width (Pro Max landscape, enlarged iPhone Mirroring) | Sidebar plus `NavigationSplitView`; item detail beside the grid; 4–5 columns. Duo owners also see this on the inner screen in v1.0 |
| Split View | Works at every width down to compact |

**v1.1 — iPhone Duo support**
| Context | Design response |
|---|---|
| Duo outer (wide and short) | Short height is a first-class layout: Quick find bar and 2 rows of cards on Home; nothing important below the fold; bars may sit vertically beside the camera |
| Duo inner (nearly square) | Full edge-to-edge version of the regular-width layout |
| Duo half-folded | Capture: camera top, items bottom. Item detail: photo above the fold, details below. Nothing on the hinge |
| Open or close the Duo | Same room and scroll position after the change |

**Design deliverables**
- **v1.0:** 4.7" SE, 6.3", 6.9", 6.9" landscape (regular width), and the largest accessibility text size.
- **v1.1:** Duo outer, Duo inner open, and Duo half-folded (PRD §4).

---

## 13. Writing style
- Warm, plain and short, addressing the user as "you". Example: "Saved to Garage."
- Answers sound like a helpful friend: "Office → Desk → Second drawer. You put them there on Aug 3."
- AI is never the hero of the sentence: say "Suggested", not "AI detected".
- Errors explain and reassure without blame: "Couldn't read this receipt. You can tap the numbers instead."
- No exclamation marks except on genuine milestones (first room documented).

---

## 14. Dark mode checklist
- Espresso canvas, never pure black; warm off-white text, never pure white.
- Elevation through lighter surfaces and hairline borders, not shadows.
- Accents lighten, and text on accent fills turns dark.
- Photos get a 1 pt hairline border so dark photos don't melt into dark cards.
- Room color fills switch to their deep versions; room symbols switch to their light inks.
- Illustrations have dark-mode versions with lowered brightness.
- Check custom content inside sheets for contrast against the darker Liquid Glass.

---

## 15. Token checklist for NookUI (P1 in the roadmap)
- [ ] Neutral, accent (×6), room (×8) and semantic Color Sets with Light, Dark and High Contrast variants
- [ ] Font tokens and `MoneyText`
- [ ] Spacing and radius tokens
- [ ] Warm shadow modifier
- [ ] Capture button, buttons, photo card, room card, answer card, breadcrumb, chips, pills, fields, toasts, skeletons, empty-state view
- [ ] Motion and haptic helpers with Reduce Motion handling
- [ ] Debug gallery showing every component in every state, light and dark, default and largest text
