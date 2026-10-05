# P1 QA report — 2026-10-05 (in progress)
Builds: `p1/close` (stacked on PRs #16–#23) · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro, iPhone 18 Pro Max, 13-inch iPad Pro (M5), iPad mini (A17 Pro)

**Status:** the automated checks below pass. The rows marked **Owner** need a real keyboard, pointer, device or Accessibility Inspector, so the phase stays *In QA* until they're done.

## Acceptance (roadmap P1)
- [x] **Builds with no warnings.** `scripts/ci.sh` reads 0 warnings from the result bundle, for the app and for test code.
- [ ] **Cold launch to Home under 400 ms on iPhone 15.** **Owner:** Instruments → App Launch on a real iPhone 15 or newer. On the simulator, `LaunchPerfTests` gives a trend (`TEST_RUNNER_RUN_PERF=1`).
- [x] **No hard-coded colors or sizes outside NookUI.** `scripts/policy-check.sh` runs in CI. Colors are generated from 03 and CI fails on drift.
- [x] **Tab bar becomes a sidebar on Pro Max landscape and iPad.** `testLandscapeOnRegularWidthShowsTheSidebar` passes on the 18 Pro Max and 13-inch iPad, and skips correctly on the SE and 18 Pro, which stay compact in landscape.
- [x] **⌘1–⌘4 switch tabs.** `testCommandNumberKeysSwitchTabs` passes on the 13-inch iPad and iPad mini (XCUITest `typeKey`). **Owner:** hardware-keyboard confirmation below.

## Phase QA
| Case | Device | Result |
|---|---|---|
| Component gallery in light and dark | SE (sim, by screenshot) | ✅ Every component matches 03 and the mockups. Chip hairlines are clean on screen. |
| Snapshots: {light, dark} × {Large, AX5} + Increase Contrast | SE (sim) | ✅ 40 references across 8 components; the AX5 truncation and overflow they found are fixed. |
| Gallery with Reduce Transparency, and the strongest and weakest Liquid Glass settings | — | **Owner:** Settings → Accessibility → Display; check the tab bar, the Capture button and the C-01 popover. |
| Increase Contrast on screen | — | **Owner:** quick look at the gallery (the snapshots already cover component colors). |
| S-06 accent and theme | SE (sim) | ✅ Plum and Dark retint the app at once and survive a relaunch (`AppearanceTests`). |
| Find on the iPad mini | iPad mini (sim) | ✅ Fixed in this PR: iOS shrank the search field to a button; it now stays open under the bar (as on the iPad boards). The large "Find" title gives way to the field there; flag it if the boards should keep both. |
| Capture placement | SE, iPad (sim) | ✅ Bottom trailing over content, never over the sidebar; a popover on iPad and a sheet on iPhone; not on compact Find (D32). |

## Hardware keyboard and pointer (D30 follow-ups) — Owner
In the 13-inch iPad simulator, turn on **I/O → Keyboard → Connect Hardware Keyboard**, then:
- [ ] ⌘1–⌘4 switch tabs; ⌘F opens Find with the field focused; ⌘, opens Nook's Settings tab.
- [ ] **⌘⌫** (debug build): shows the toast "Delete shortcut received." If nothing happens, Delete keeps only its menu item, per D30.
- [ ] Hold ⌘ to see the shortcut list, and take a screenshot of the menu bar (swipe down from the top with the pointer). Compare with the `iPadMenu` board.
- [ ] Pointer hover: photo cards and room cards lift in the gallery.

## Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1 | iPhone SE (sim) | ✅ | Light and dark launch to Home; tab bar and Capture visible (`ShellTests`, 5 passed) |
| S1 | iPhone 18 Pro (sim) | ✅ | Compact in landscape (tab bar), as expected |
| S1 | iPhone 18 Pro Max (sim) | ✅ | Sidebar in landscape |
| S1 | 13-inch iPad (sim) | ✅ | Sidebar in landscape; ⌘1–⌘4 (7 passed) |
| S1 | iPad mini (sim) | ✅ | 7 passed |
| S1 | Resized iPad window | **Owner** | Resize to narrow in Stage Manager: it switches to the tab bar and keeps the tab (`@SceneStorage`) |

## Accessibility (screens touched: shell, S-01, S-06, the components)
- [x] VoiceOver labels: Capture (label and hint); cards read name, location and value; accent swatches read "Terracotta, selected"; headings are marked; the toast is announced.
- [x] Dynamic Type to AX5: by snapshot, plus the SE at AX5 in the simulator. Grids become one column; nothing essential truncates.
- [x] Reduce Motion: press, shimmer and the toast fall back to fades or none (in the tokens).
- [ ] **Owner:** Accessibility Inspector audit on Home, Settings, Appearance and the gallery; no new warnings.

## No-AI check
n/a: the router isn't touched in P1.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | Snapshot images show faint edge lines on short rounded shapes (chips, short toast). It's a `layer.render` artifact only; the app renders cleanly. |
| — | P3 | The C-01 popover stays open across a tab switch (system popover behavior); revisit when C-01 gets real rows in P6. |
