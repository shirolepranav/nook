---
name: build-screen
description: Build or modify a Nook SwiftUI screen or NookUI component to spec — tokens, all states, accessibility, Dynamic Type, Reduce Motion, compact/regular/iPhone Duo layouts, and previews. Use for any UI work in Nook/Features or Packages/NookUI.
---

# Build a screen

A Nook screen is "done" only when it matches the spec in every state, size and accessibility setting. Design comes first in this product (PRD principle 1).

## 1. Gather the spec
- Find the screen's section in `docs/01_Pages_UI_Interactions.md`: **Purpose, Elements, Interactions, States, Adaptive, A11y, Traces**.
- Read the `03_Design_System.md` sections for every component you'll use, plus §9 Motion, §10 Haptics and §11 Accessibility.
- Check `docs/decisions.md` for anything affecting this screen (D2 navigation, D5 colors, D6 spacing…).
- Check the global conventions in `01 §0`: states, destructive actions, AI-as-suggestion, free limits, Private items, Hide values.
- Open the matching mockup in `design/screens/` (index in `design/README.md`). It wins on visual detail. The docs win on behavior. Map every value to a NookUI token; never copy literals.

## 2. Reuse before you build
- Look in `Packages/NookUI/Sources/NookUI/Components` and use the existing `NookCard`, `PhotoCard`, rows, chips, pills, `PriceText`, breadcrumb, states and toast.
- Add a new component to NookUI only if at least 2 screens need it. Otherwise keep it private to the feature folder.

## 3. Structure
- `Nook/Features/<Feature>/<Name>Screen.swift`, plus subviews, plus an `@Observable <Name>Model` if the state is non-trivial.
- Screens call **services** (NookKit), never engines or `FoundationModels` directly. For AI-assisted content, render the router's result type. The UI is identical for both engines.
- Free-limit checks come from `EntitlementStore`. On a limit, present the Paywall (`01 §8`). Never disable viewing data the user already entered.

## 4. Non-negotiables checklist
**Visual**
- [ ] Tokens only: `NookColor`, the accent via `.tint`, `Font.nook*`, `NookSpace`, radii, `nookShadow`, `NookMotion`. No literals.
- [ ] Content on opaque paper (`surface`/`canvas`). Glass only on native bars and floating controls. Never glass on glass.
- [ ] Concentric corners (`ConcentricRectangle` + `.containerShape`), continuous style.
- [ ] Status shown with icon + text + color, never color alone.

**States**, each designed with an illustration, one sentence and one action where relevant:
- [ ] loading (skeleton; no spinner over 300 ms)
- [ ] empty
- [ ] filtered-empty
- [ ] error (plain copy, Retry, never mentions AI)
- [ ] success (toast + haptic, Undo if reversible)

**Adaptive** (size classes only, never `UIScreen.main` or device checks)
- [ ] Compact: single column, 2-column photo grid.
- [ ] Regular: split view / sidebar, 4–5 columns via adaptive `GridItem`, detail beside the list.
- [ ] Duo: half-fold uses `ReservedRegion` where the spec says [Verify in SDK]; the outer screen's short height keeps essentials above the fold; per-edge safe areas.
- [ ] State survives fold/unfold and relaunch (`@SceneStorage` for the selection, path and scroll anchor).

**Accessibility**
- [ ] Cards are combined into one element whose label includes **name, room and value**.
- [ ] Custom actions mirror swipes and context menus.
- [ ] Headings are marked. Toasts and coach hints are announced.
- [ ] Dynamic Type to AX5: grids become lists (`dynamicTypeSize.isAccessibilitySize`), rows stack (`ViewThatFits`), nothing essential is truncated.
- [ ] Reduce Motion: cross-fades instead of zoom, slide or bounce; haptics kept.
- [ ] Targets ≥ 44×44 pt. Voice Control names match the visible text.
- [ ] Every action is reachable without the camera and without AI.

**Motion & haptics**
- [ ] Only the events listed in 03 §9–10: zoom transition from `PhotoCard`, `settle` after save or move, `.success` on real success only, `.selection` on pickers.

**Copy**
- [ ] Warm, plain and short, in `Localizable.xcstrings`. AI output labeled "Suggested" or "Estimate".

## 5. Previews & tests
- `#Preview`s for every state (empty, loaded, error), dark mode, AX5, and a regular-width trait. Use `PreviewStore.seeded(.small)`.
- Snapshot tests for new NookUI components: {light, dark} × {Large, AX3}.
- A UI test for the screen's primary flow if it's part of US1–US6 or a smoke-suite row.

## 6. Verify visually before the PR
Run it in the simulator on **iPhone SE** and **18 Pro Max**, plus a **Duo configuration** in Device Hub if the layout is adaptive. Take screenshots in light, dark and AX3 for the PR. Run Accessibility Inspector's audit, then fix issues or explain them in the PR.
