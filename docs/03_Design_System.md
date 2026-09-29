# Nook Design System — "Warm Linen"

**Direction:** calm, tactile and personal, like a well-organized home rather than a spreadsheet (PRD §3).
**Target:** iOS 27 (Liquid Glass era, with no opt-out). Implemented in the **NookUI** package.

- **Rule for code:** no color, font, spacing, radius, shadow, animation or haptic literal appears outside NookUI. Use the tokens below. CI greps for `Color(red:`, `Color(#`, `.font(.system(size:` and `.padding(<number>)` in the app target.
- **Precedence:** [00_PRD.md](00_PRD.md) > [decisions.md](decisions.md) > this doc.
- **Contrast:** every contrast figure below was calculated with WCAG 2.x relative luminance. Re-verify in Accessibility Inspector on device in P1.

---

## 1. Principles
1. **Photos are the interface.** Items are large photo cards, and a room looks like a well-lit shelf. Text rows are the fallback: in list mode, and at accessibility sizes.
2. **Paper for content, glass for controls.** Cards, lists, forms and photos are opaque warm "paper". Liquid Glass is reserved for the functional layer: the tab bar/sidebar, toolbars, sheets at partial detents, the floating Capture button, and transient controls. **Never put glass on content, and never stack glass on glass.** Apple's HIG and WWDC25 "Meet Liquid Glass" say that glass belongs to the navigation layer floating above content.
3. **One obvious action per screen.** One primary button, at most. Capture is always one tap away.
4. **Kind to mistakes.** Undo toasts, drafts, and Recently Deleted. AI output is visibly a *suggestion*: a subtle "Suggested" tint until the user edits or accepts it.
5. **Quiet by default.** No badges, streaks or nagging. Color signals status only when it matters.
6. **Tactile feedback.** Meaningful moments get a soft spring, a light haptic and a satisfying "settle".
7. **Legible everywhere:**
   - Any Liquid Glass slider position (Settings → Appearance → Liquid Glass)
   - Reduce Transparency and Increase Contrast
   - Bold Text
   - Dynamic Type up to AX5
8. **Native first.** Use system components with tokens applied, so the app inherits platform improvements for free.

---

## 2. Color

Colors live in Asset Catalog color sets with Any, Dark and High Contrast variants, exposed through `NookColor`. The minimums are 4.5:1 for body text, and 3:1 for large text and essential icons. The dark theme is not an inversion of the light theme: surfaces get *lighter* as they rise, accents lift in lightness, and there is never pure black or pure white.

### 2.1 Neutrals & surfaces
| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | #FAF6F0 (linen) | #1C1814 (espresso) | App background |
| `surface` | #FFFDF9 | #26211C | Cards, rows |
| `surfaceRaised` | #FFFFFF | #2F2923 | Toasts, popovers, dragged cards |
| `surfaceSunken` | #F2EBE1 | #15120F | Input wells, photo placeholders |
| `hairline` | #E6DDD1 | #3A332C | Dividers, card borders, 1-pt photo edge in dark |
| `textPrimary` | #2B2420 (15.0:1 on surface) | #F4EDE4 (13.7:1) | Titles, body |
| `textSecondary` | #6B5F57 (6.1:1) | #BFB3A7 (7.8:1) | Metadata |
| `textTertiary` | #8C8079 (3.8:1) | #8F847A (4.4:1) | **Placeholders only, never essential info** |

### 2.2 Accent: 6 the user can pick (D5)
The accent tints selection, primary buttons, links and native glass controls, via `.tint()` at the root. It is stored in `@AppStorage("accent")`, and the default is **Terracotta**.

| Accent | `accent` Light | `accent` Dark | `accentText` Light¹ | `accentSoft` Light | `accentSoft` Dark |
|---|---|---|---|---|---|
| **Terracotta** (default) | #B5522E | #E98A64 | #9E4424 | #F8ECE5 | #453228 |
| Sage | #4F7A57 | #8FBF97 | #436A4A | #EDF0E9 | #373A30 |
| Ocean | #2F6F7A | #7CC3CC | = accent | #EAEFEC | #343B38 |
| Plum | #7A4E86 | #C49AD0 | = accent | #F2ECEE | #3F3439 |
| Slate | #4A5A78 | #A3B3D1 | = accent | #EDEDEC | #3A3839 |
| Rose | #A4476A | #E796B4 | = accent | #F6EBEB | #453434 |

- `onAccent` is #FFFFFF in light and #1C1814 in dark. Every light accent passes ≥ 4.9:1 with white text, and every dark accent passes ≥ 6.9:1 with espresso text.
- ¹ Use `accentText` for **accent-colored text on `accentSoft`** (secondary buttons, selected chips). Terracotta and Sage at full strength reach only about 4.3:1 on their soft tint. `accentText` lifts them to ≥ 5.3:1.
- An alternate app icon is offered per accent (optional, P11).

### 2.3 Semantic
| Token | Light | Dark | Use |
|---|---|---|---|
| `honey` | #945C0E (5.4:1) | #E3A948 | Warranty ending ≤ 30 days, loan overdue, "Check this" |
| `success` (moss) | #3F7D4E | #7CBF8A | Warranty active, saved, "It's here ✓" |
| `danger` (brick) | #B3261E | #F2857A | Ending ≤ 7 days, destructive |
| `info` (blue-slate) | #3D6B8C | #8DB7D6 | Tips, sync info |
| `suggested` | `accentSoft` at 60% | `accentSoft` at 60% | Background of AI-filled fields not yet confirmed |

**Rule:** status is never shown by color alone. Always use icon + text + color ("⚠︎ Ends in 12 days").

### 2.4 Room colors (8 soft tints, D5)
Room colors are used for room card headers, the chips in the Spots row, widget accents and the sidebar dots. **On a room tint, use `textPrimary` for text** (≥ 8.9:1). `textSecondary` only reaches 4.3–4.9:1 there, so it is limited to text 18 pt and larger.

| Room color | Light | Dark |
|---|---|---|
| Clay | #EBD3C5 | #4A3328 |
| Sage | #D5E1D1 | #33403A |
| Sky | #D0DFEA | #2E3B45 |
| Butter | #F1E4BF | #4A3F26 |
| Lilac | #E0D5E7 | #3D3444 |
| Rose | #F0D4DA | #4A3339 |
| Stone | #E2DCD2 | #403A34 |
| Mint | #CFE6DE | #2B413B |

Onboarding assigns room colors in order. The user can change a room's color in the room editor.

```swift
// NookUI/Sources/NookUI/Tokens/NookColor.swift
import SwiftUI

/// Every color in the app. Each case maps to an Asset Catalog color set
/// with Light, Dark and High Contrast variants.
public enum NookColor {
    public static let canvas        = Color("canvas", bundle: .module)
    public static let surface       = Color("surface", bundle: .module)
    public static let surfaceRaised = Color("surfaceRaised", bundle: .module)
    public static let surfaceSunken = Color("surfaceSunken", bundle: .module)
    public static let hairline      = Color("hairline", bundle: .module)
    public static let textPrimary   = Color("textPrimary", bundle: .module)
    public static let textSecondary = Color("textSecondary", bundle: .module)
    public static let honey         = Color("honey", bundle: .module)
    public static let success       = Color("success", bundle: .module)
    public static let danger        = Color("danger", bundle: .module)
    public static let info          = Color("info", bundle: .module)
}

/// The 6 accents the user can pick. Stored by rawValue in @AppStorage("accent").
public enum NookAccent: String, CaseIterable, Sendable {
    case terracotta, sage, ocean, plum, slate, rose

    public var color: Color     { Color("accent.\(rawValue)", bundle: .module) }
    public var text: Color      { Color("accentText.\(rawValue)", bundle: .module) }
    public var soft: Color      { Color("accentSoft.\(rawValue)", bundle: .module) }
}

/// The 8 soft room tints. Stored on Room.colorKey.
public enum RoomColor: String, CaseIterable, Sendable {
    case clay, sage, sky, butter, lilac, rose, stone, mint
    public var color: Color { Color("room.\(rawValue)", bundle: .module) }
}
```

---

## 3. Typography

- **SF Pro** for body text and data, with Dynamic Type everywhere.
- **SF Pro Rounded** (`.fontDesign(.rounded)`) for large headings and **totals** (PRD visual system).
- Numbers use `.monospacedDigit()` so values don't "wiggle" as they change.
- Always use text styles. Never use fixed sizes.

| Token | Text style | Default pt | Weight | Design | Use |
|---|---|---|---|---|---|
| `display` | .largeTitle | 34 | Bold | Rounded | Tab root titles |
| `title` | .title2 | 22 | Semibold | Rounded | Detail headers, room names |
| `section` | .title3 | 20 | Semibold | Rounded | Card titles |
| `headline` | .headline | 17 | Semibold | Default | Card and row titles |
| `body` | .body | 17 | Regular | Default | Body text, fields |
| `meta` | .subheadline | 15 | Regular | Default | Breadcrumbs, metadata |
| `footnote` | .footnote | 13 | Regular | Default | "Last confirmed Aug 3", timestamps |
| `caption` | .caption | 12 | Medium | Rounded | Chips, pills |
| `value` | .title3 | 20 | Semibold | Rounded + mono digits | Prices, counts |
| `total` | .largeTitle | 34 | Bold | Rounded + mono digits | Home total value |
| `serial` | .body | 17 | Regular | Monospaced | Serial and model numbers |

**Dynamic Type rules:**
- Test from xSmall through AX5.
- At accessibility sizes (`dynamicTypeSize.isAccessibilitySize`), **photo grids become lists** and horizontal rows stack vertically (`ViewThatFits`).
- Essential info wraps; it is never truncated. Serials middle-truncate but are fully readable in VoiceOver and on copy.
- Custom metrics use `@ScaledMetric`.

```swift
// NookUI/Sources/NookUI/Tokens/NookFont.swift
import SwiftUI

public extension Font {
    static let nookDisplay  = Font.largeTitle.weight(.bold)
    static let nookTitle    = Font.title2.weight(.semibold)
    static let nookSection  = Font.title3.weight(.semibold)
    static let nookHeadline = Font.headline
    static let nookBody     = Font.body
    static let nookMeta     = Font.subheadline
    static let nookFootnote = Font.footnote
    static let nookCaption  = Font.caption.weight(.medium)
    static let nookValue    = Font.title3.weight(.semibold)
}

/// A currency amount in the app's value style. Honors "Hide values" (F11).
public struct PriceText: View {
    let amount: Decimal
    let currencyCode: String
    @Environment(\.hideValues) private var hideValues   // NookUI environment key

    public init(_ amount: Decimal, currencyCode: String) {
        self.amount = amount; self.currencyCode = currencyCode
    }

    public var body: some View {
        Group {
            if hideValues { Text("•••").accessibilityLabel("Value hidden") }
            else { Text(amount, format: .currency(code: currencyCode)) }
        }
        .font(.nookValue)
        .fontDesign(.rounded)
        .monospacedDigit()
        .foregroundStyle(NookColor.textPrimary)
    }
}
```

---

## 4. Spacing & layout (8-pt grid, D6)

| Token | pt | Use |
|---|---|---|
| `half` | 4 | **Only** chip/pill internals and icon-to-label gaps |
| `s1` | 8 | Tight stacks |
| `s2` | 16 | Card padding, side margins (compact) |
| `s3` | 24 | Section gaps, side margins (regular) |
| `s4` | 32 | Screen-level breathing room |
| `s6` | 48 | Empty-state spacing |

- Card gap: 16. Rows are at least 56 pt tall (72 pt with a thumbnail). Touch targets are at least 44×44 pt with at least 8 pt between them.
- **Photo grid columns:**
  - Compact: 2 (3 on Pro Max landscape).
  - Regular: 4–5, computed from the available width with `GridItem(.adaptive(minimum: 160))`. Never from the device type.
  - At accessibility sizes: a list.
- Use readable content width for text-heavy screens at regular width.

```swift
public enum NookSpace {
    public static let half: CGFloat = 4
    public static let s1: CGFloat = 8
    public static let s2: CGFloat = 16
    public static let s3: CGFloat = 24
    public static let s4: CGFloat = 32
    public static let s6: CGFloat = 48
}

/// Card padding that grows a little with Dynamic Type.
public struct CardPadding: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var pad: CGFloat = NookSpace.s2
    public func body(content: Content) -> some View { content.padding(pad) }
}
```

---

## 5. Shape: concentric, continuous, pillowy

| Token | Radius | Use |
|---|---|---|
| `xs` | 8 | Tags, small thumbnails |
| `sm` | 12 | Row thumbnails, inputs |
| `md` | 16 | Inner photo in a card |
| `lg` | 24 | Cards, photo cards |
| `xl` | 32 | Hero / room header |
| capsule | — | Chips, pills, primary buttons, toasts |

- Corners are always continuous.
- **Nested shapes are concentric:** the inner radius equals the outer radius minus the padding. Use `ConcentricRectangle` with `.containerShape(...)` so cards also follow each screen's corner shape, including the iPhone Duo's (PRD §4 rule 7).

```swift
/// Opaque "paper" card: the base container for all content.
public struct NookCard<Content: View>: View {
    @ViewBuilder var content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .modifier(CardPadding())
            .background(NookColor.surface, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(NookColor.hairline, lineWidth: 1)
            )
            .containerShape(.rect(cornerRadius: 24))   // inner ConcentricRectangle() derives from this
            .nookShadow(.low)
    }
}
```

---

## 6. Elevation, materials & Liquid Glass

There are three layers:
1. **Canvas:** flat linen.
2. **Content:** opaque paper cards. In light mode, a warm diffuse shadow. In dark mode, elevation comes from a lighter surface plus a hairline.
3. **Functional:** system Liquid Glass, which we only tint.

| Elevation | Light (warm brown #5A3A22 shadow) | Dark |
|---|---|---|
| `flat` | none | none |
| `low` (cards) | y2 blur8 6% + y1 blur2 4% | surface + hairline |
| `mid` (pressed / dragging) | y8 blur20 10% | surfaceRaised + hairline |
| `high` (toast, popover) | y16 blur32 14% | surfaceRaised + lighter border |

**Liquid Glass rules:**
- Use native bars. For floating controls (the Capture button), use `.buttonStyle(.glass)` or `.glassProminent`. Group custom glass in a `GlassEffectContainer`.
- **Never** put `.glassEffect()` on cards, rows, photos or toasts. Don't put glass over flat single-color areas.
- Check both extremes of the glass slider, plus Reduce Transparency (frosty) and Increase Contrast (black/white with a border).
- Scroll edge: accept the iOS 27 automatic style [Verify in SDK: the reported "hard" default]. Use `.soft` only on photo-heavy screens, and only after a legibility test.
- In iOS 27 the dark glass is lighter [Verify in SDK], so re-check contrast on custom content inside sheets.
- Optional tactility: a 2–3% paper-grain texture on `canvas` only. Remove it under Increase Contrast.

```swift
public enum NookElevation { case low, mid, high }

public extension View {
    func nookShadow(_ level: NookElevation) -> some View { modifier(WarmShadow(level: level)) }
}

struct WarmShadow: ViewModifier {
    let level: NookElevation
    @Environment(\.colorScheme) private var scheme
    private let tint = Color(red: 0.35, green: 0.23, blue: 0.13)   // warm brown (token source of truth)

    func body(content: Content) -> some View {
        if scheme == .dark {
            content   // dark mode: lighter surfaces + hairlines, not shadows
        } else {
            switch level {
            case .low:
                content
                    .shadow(color: tint.opacity(0.06), radius: 8, y: 2)
                    .shadow(color: tint.opacity(0.04), radius: 2, y: 1)
            case .mid:  content.shadow(color: tint.opacity(0.10), radius: 20, y: 8)
            case .high: content.shadow(color: tint.opacity(0.14), radius: 32, y: 16)
            }
        }
    }
}
```

---

## 7. Iconography & illustration
- **SF Symbols 7 only** (PRD). Hierarchical rendering by default. Room symbols use palette rendering in the room color. Use variable color for progress and signal (sync, scan). Symbol weight follows the adjacent text.
- **Symbol effects:**
  - The checkmark *draws on* when saving.
  - `.bounce` on "It's here ✓".
  - Variable draw for report-generation progress.
  - All of them respect Reduce Motion.
- **Default room symbols:**

  | Room | Symbol |
  |---|---|
  | Kitchen | `fork.knife` |
  | Living room | `sofa` |
  | Bedroom | `bed.double` |
  | Bathroom | `shower` |
  | Office | `desktopcomputer` |
  | Garage | `car` |
  | Basement | `stairs` |
  | Storage | `shippingbox` |
  | Custom | `house` |

- **Illustrations:** soft, rounded clay/gouache style in the warm palette. They are decorative only (`accessibilityHidden(true)`), and every empty, error and onboarding screen has one.
- **App icon:** a layered Icon Composer mark (a warm "nook" shelf or house) with light, dark, clear and tinted variants.

---

## 8. Components (NookUI)

### 8.1 Buttons
| Variant | Look | Use |
|---|---|---|
| Primary | Capsule, `accent` fill, `onAccent` label, 50 pt | One per screen: Save, Save all, Move, Continue |
| Secondary | Capsule, `accentSoft` fill, `accentText` label, 44–50 pt | Alternatives |
| Tertiary | Text in `accentText` | Links, Cancel-like actions |
| Destructive | `danger` label (fill only in confirm dialogs) | Delete |
| Glass | `.glass` / `.glassProminent` | **Floating controls only** (Capture) |

- **States:**
  - Pressed: scale 0.97 with the `tap` spring.
  - Disabled: 40% opacity, no haptic.
  - Loading: a `ProgressView` with the width locked.

```swift
public struct NookPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).fontDesign(.rounded)
            .foregroundStyle(.white)                               // onAccent (dark variant via asset in real impl)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.tint, in: .capsule)                       // tint = user's accent
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(NookMotion.tap, value: configuration.isPressed)
    }
}
```

### 8.2 Capture button (floating, D2)
- A 56-pt circle using `.glassProminent`, tinted with the accent, with a `plus.viewfinder` symbol and the accessibility label "Capture".
- It sits above the tab bar at the trailing edge in compact width, and at the bottom trailing of the detail column in regular width. It respects per-edge safe areas on the Duo.
- Tap opens the Capture menu. Long-press goes to Scan room with an `.impact(weight: .light)` haptic.
- It hides while the keyboard is up and inside editors and sheets.
- Final placement is decided in P1 (overlay vs `tabViewBottomAccessory`) and logged in decisions.md.

### 8.3 Photo cards, rows & the shelf
- **PhotoCard** (item):
  - A 4:3 photo with a concentric clip.
  - The name (headline, 2 lines), and the value (`value`, mono, respecting Hide values).
  - Optional badges in the top trailing corner: warranty ribbon (honey/danger), "Lent" (info), a lock (Private).
  - Pressed: lifts to `mid` and scales to 0.98.
  - It is the source of the **zoom transition** to Item Detail (`.matchedTransitionSource` + `.navigationTransition(.zoom)`).
- **RoomCard:**
  - A room-tint header with a palette symbol, a mosaic of up to 4 recent photos, and the name, count and value.
- **Shelf:** the room grid, grouped by spot with sticky section headers (spot name plus spot photo thumbnail).
- **Row** (list mode and AX sizes):
  - A 56-pt thumbnail, the title, and a breadcrumb subtitle.
  - A trailing value or status and a chevron.
  - Swipe actions: leading is constructive (Move = accent, Lend = info), trailing is destructive (Delete = danger).

### 8.4 Location components
- **Breadcrumb:** "Office › Desk › Second drawer". Uses `meta`, and the last segment is semibold. It wraps rather than truncates. VoiceOver reads "Office, then Desk, then Second drawer".
- **Answer card:**
  - A `surfaceRaised` card with the item photo and spot photo side by side, the breadcrumb, "You put them there on Aug 3", and the **last-confirmed** footnote.
  - Buttons: Move (primary), "Found it here instead" (tertiary), and "It's here ✓" (secondary).
- **Move-confirm card** `[AI]`: "Move **Passports** to **Bedroom › Safe**?" with Move (primary) and Cancel.

### 8.5 Inputs, chips, pills
- **Text field:**
  - A `surfaceSunken` well with a 12-pt radius and a height of at least 48 pt.
  - The label sits above the field, and the helper or error text below.
  - Focus: a 2-pt accent border. Error: a `danger` border, an icon and a message.
- **Suggested (AI) field:** a `suggested` background and a small ✦ icon until the user edits or accepts the value. VoiceOver says "Suggested".
- **Special fields:**
  - Currency: locale-aware, decimal pad.
  - Date: a compact `DatePicker`.
  - Serial: monospaced, with "Scan".
  - Tags: a token field.
  - Photos: a grid of up to 10, draggable to reorder.
- **Chips:**
  - Filter chips are 32-pt capsules with a 44-pt hit area.
  - Selected: an `accentSoft` fill, `accentText` label and a checkmark.
  - Room chips use the room tint.
- **Status pills** always pair an icon with text:

  | Status | Color |
  |---|---|
  | Active | success |
  | Ending | honey |
  | Ending in ≤ 7 days | danger |
  | Expired | textSecondary on surfaceSunken |
  | Lent | info |
  | Overdue | honey |

### 8.6 Scan overlay (room scan, F3)
- **Detected-item outline:**
  - A 2-pt rounded rectangle in the accent over the photo, with a 12% `accentSoft` fill.
  - It draws on over 0.25 s. Each outline also has a numbered caption chip that matches its card.
  - Selected outline: 3 pt plus the `mid` shadow on the matching card.
- **Detection cascade:** outlines appear **one after another**, 120 ms apart, each with `.impact(weight: .light, intensity: 0.6)`. The cards stream in below in the same order. Under Reduce Motion the outlines fade in with the haptics kept, and the cascade cap is 10 haptics.
- **Manual tagging box:**
  - Drawing with a drag shows a dashed accent border. When released, it becomes solid and the name field focuses.
  - The box can be resized with its corner handles (44-pt hit areas).
- **Coach overlay:** a glass capsule at the top of the camera with one short hint at a time. It changes at most every 2 s and is announced to VoiceOver.

### 8.7 Sheets & dialogs
- Use native sheets, which are glass at partial detents.
  - `.medium`: the Capture menu, Move picker, Lend sheet.
  - `.large`: editors.
  - Show a grabber on resizable sheets. Editors use Cancel / Save.
- Custom content inside sheets stays opaque.
- Confirmation dialogs spring from the control that triggered them, and label destructive options explicitly ("Delete 3 Items").

### 8.8 Tab bar, sidebar, toolbars (D2)
- The tab bar shows **Home** (`house`), **Find** (`Tab(role: .search)`), **Reports** (`doc.text.magnifyingglass`) and **Settings** (`gearshape`).
- No badges (principle 5).
- The tab bar stays visible: `.tabBarMinimizeBehavior(.never)` [Verify in SDK].
- No custom bar backgrounds. Tint only.
- Large rounded titles on tab roots, inline titles on detail screens. The primary action is pinned trailing, secondary actions go in the overflow menu. Content scrolls under the bars.

```swift
struct RootView: View {
    @AppStorage("accent") private var accent: NookAccent = .terracotta
    @State private var showCapture = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeScreen() }
            Tab("Reports", systemImage: "doc.text.magnifyingglass") { ReportsScreen() }
            Tab("Settings", systemImage: "gearshape") { SettingsScreen() }
            Tab(role: .search) { FindScreen() }                  // system search tab placement
        }
        .tabViewStyle(.sidebarAdaptable)                         // sidebar at regular width
        .tint(accent.color)                                      // also tints native glass
        .overlay(alignment: .bottomTrailing) {                   // placement finalized in P1 (D2)
            CaptureButton { showCapture = true }
        }
        .sheet(isPresented: $showCapture) { CaptureMenu() }
    }
}
```

### 8.9 Empty, loading, error, success
- **Empty:**
  - A 120–160 pt illustration, a `section` rounded title, one sentence and one primary button.
  - Example: "Nothing here yet. Scan this room to fill it in 30 seconds."
- **Loading:**
  - Skeleton paper blocks with a slow warm shimmer. The shimmer is static under Reduce Motion.
  - Never show a spinner for more than 300 ms.
- **Error:**
  - `exclamationmark.bubble`, a plain-language reason, and Retry.
  - The copy never blames the user and never mentions AI.
- **Toast:**
  - A bottom capsule on `surfaceRaised` with the `high` elevation. It is **not glass**.
  - It holds an icon, a message and an optional action (Undo or "Add another").
  - It lasts 4 s (5 s when it has Undo) and is announced to VoiceOver.
- **Warranty ring:**
  - A 6-pt stroke in the status color.
  - Its accessible value reads, for example, "142 days remaining of 365".

---

## 9. Motion

| Token | Definition | Use |
|---|---|---|
| `tap` | `.snappy(duration: 0.2)` | Press, toggle |
| `settle` | `.spring(duration: 0.45, bounce: 0.25)` | A card settles into the grid after a save or move |
| `gentle` | `.smooth(duration: 0.35)` | Filters, content changes |
| `cascade` | 120 ms stagger + `settle` | AI detection outlines and cards |
| `celebrate` | `.bouncy(duration: 0.6)` | Onboarding complete, Pro unlocked |
| zoom | `.navigationTransition(.zoom(sourceID:in:))` | Photo card → Item Detail (PRD) |

- Motion explains cause and effect.
- Nothing lasts longer than 0.6 s. Only the loading shimmer loops.
- **Reduce Motion:**
  - Cross-fades replace zoom, scale, slide and bounce.
  - No parallax or shake. The failure shake becomes a color pulse.
  - Haptics stay.

```swift
public enum NookMotion {
    public static let tap       = Animation.snappy(duration: 0.2)
    public static let settle    = Animation.spring(duration: 0.45, bounce: 0.25)
    public static let gentle    = Animation.smooth(duration: 0.35)
    public static let celebrate = Animation.bouncy(duration: 0.6)
    public static let cascadeStep: Duration = .milliseconds(120)
}

/// "Settle in" entrance that respects Reduce Motion.
public struct SettleIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : NookMotion.settle) { appeared = true }
            }
    }
}
```

---

## 10. Haptics

Haptics use declarative `sensoryFeedback`. Some devices have no haptics, and users can turn them off, so **meaning never relies on haptics alone**.

| Event | Feedback |
|---|---|
| Item saved, Save all, warranty added, scan recognized, "It's here ✓" | `.success` |
| Each AI-detected item (cascade) | `.impact(weight: .light, intensity: 0.6)` |
| Photo captured | `.impact(weight: .light)` |
| Chip toggled, picker or segment changed | `.selection` |
| Move dropped, reorder snap | `.alignment` |
| Validation or unlock failed | `.error` |
| Warranty-ending banner (once per session) | `.warning` |

```swift
struct SaveButton: View {
    @State private var saveCount = 0
    var onSave: () async -> Bool
    var body: some View {
        Button("Save") { Task { if await onSave() { saveCount += 1 } } }
            .buttonStyle(NookPrimaryButtonStyle())
            .sensoryFeedback(.success, trigger: saveCount)   // only fires on real success
    }
}
```

---

## 11. Accessibility (a release requirement)

- **Contrast:** 4.5:1 for text, 3:1 for large text and UI. Every token has a High Contrast variant. Check at both glass-slider extremes.
- **VoiceOver:**
  - **Every card is labeled with its name, room and value:** "Dyson V15 vacuum, Living room, 499 dollars, warranty ends in 42 days".
  - Cards use `.accessibilityElement(children: .combine)`.
  - **Custom actions mirror swipes and context menus**: Move, Lend, Delete.
  - Section headers have the heading trait.
  - Toasts and the scan coach are announced.
- **Dynamic Type:** the layout reflows up to AX5 and grids become lists. No text is baked into images.
- **Honor these settings:** Reduce Motion, Reduce Transparency, Increase Contrast, Bold Text, Button Shapes, Smart Invert (photos use `accessibilityIgnoresInvertColors`).
- **Voice Control:** labels match the visible text. Targets are at least 44 pt with at least 8 pt between them.
- **No camera, no AI:** every action is reachable without either (PRD). Room scan offers "Add item without drawing".
- **Tools:** Xcode 27 Device Hub (appearance, text size and accessibility toggles) and Accessibility Inspector, every phase. The App Store Accessibility Nutrition Label is filled in honestly (P11).

---

## 12. Voice & writing

- **Warm, plain, second person, and short:** "Saved to Kitchen." "Moved to Bedroom › Safe." "Nothing here yet."
- **Numbers over adjectives:** "Ends in 12 days", not "Ending soon!".
- **Never mention "AI" in errors.** When the AI path fails, the manual path simply appears ("Tap items to add them.").
- **Label AI estimates "Estimate"**, and label AI-filled fields "Suggested".
- **Permissions lead with the benefit**, in one line (01 §10).
- **Dark mode:**
  - An espresso canvas, never pure black. Warm off-white text, never pure white.
  - Elevation comes from lighter surfaces and hairlines, and photos get a 1-pt hairline.
  - Accents are lifted, with dark text on accent fills.
