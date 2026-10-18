# P13 QA report — 2026-10-17
Builds: `p13/polish-release` · Xcode 27.0 (27A266a) · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), iPhone 18 Pro Max, 13-inch iPad Pro (M5). Dedicated P13 simulators were used, because the CI runner shares the named ones. Real-device checks are listed under **Owner**.

The owner's choices are in D63:
- S-10 and S-12 were built in P13.
- Crash-free sessions come from Organizer and App Store Connect.
- The support address is lightconeapps@gmail.com.

Every finding is recorded in D63.

## What P13 found and fixed
| Finding | Severity | Fix |
|---|---|---|
| The Release build didn't compile. `#Preview` bodies used debug-only stores, so no archive was possible | P0 | Previews are debug-only. CI now builds Release for devices and checks no UI-testing switch ships |
| No privacy manifests | P1 (App Store) | App and widget manifests, with no tracking or collected data. Required-reason APIs: UserDefaults (CA92.1, 1C8F.1), file timestamps (C617.1) |
| Fast-scrolling a 1,000-card grid deadlocked thumbnail loading (parallel HEIC decodes) | P1 | `BlobStore` decodes one image at a time on a serial queue |
| F3's timing test failing since P6: a spring `scrollTo` in C-04 never finished, so the app never went idle | P2 | An eased scroll. 8 items now take 51 s on the SE (budget 120 s) |
| P8-1, the first Capture tap ignored | — | Not a Nook bug: the iOS 27 simulator drops the first tap after any app comes to the front, Apple's Settings included. **Owner:** confirm on a device |
| S-10 Tags and S-12 Help & About were never built | P1 (scope) | Built from their boards (D63) |
| A typed Settings path couldn't push S-10's values | P1 | S-01 uses a `NavigationPath`, and the Tags row is a value link |
| P3 polish bugs: the toast covered Capture, "Found It Here Instead" wrapped on the SE, the "Try asking" grammar, Private names still masked after an unlock, two chevrons on the Pro card, moves from grids with no success haptic | P3 | Fixed |
| Photos inverted by Smart Invert on the capture screens; cards' long labels for Voice Control | P2 (a11y) | `accessibilityIgnoresInvertColors` on every photo; visible names as input labels |

## Acceptance (roadmap P13)
- [ ] **Zero known crash or data-loss bugs:** none open from P13's runs (see Open bugs). Beta crash data still to come (**Owner**, TestFlight).
- [ ] **Crash-free sessions ≥ 99.8% in beta:** measured in Organizer and App Store Connect (D63). **Owner:** needs TestFlight, which needs Gate 3's App Store Connect setup (D60).
- [ ] **All PRD §9 performance budgets met:** see Performance. The simulator numbers pass or give a trend. The device budgets are **Owner**.

## Phase QA
| Case | Where | Result |
|---|---|---|
| Motion and haptics against 03 §9–10 | code walk, UI tests | ✅ Button press 97%; zoom on every grid; `saved` haptic on every save and move through the toast; `tick` on outlines, codes and the shutter; `selected` on chips and pickers; raw motion and haptics fail a new policy grep |
| Accessibility audit on every screen | `AccessibilityAuditTests` (14 tests) | ✅ All 14 audits pass on the SE and the 13-inch iPad, `testP13ScreensPassTheAccessibilityAudit` included |
| Voice Control, Smart Invert, Bold Text, Differentiate Without Color | code walk | ✅ Input labels on cards; every photo surface ignores invert; status is always icon plus text. **Owner:** Voice Control and the Liquid Glass slider on a device (D33) |
| Regular width: Pro Max landscape, 13-inch iPad | App Store screenshot run, audits on iPad | ✅ Content stays within `readableWidth`, the item column sits beside the list, and Find's answer shows beside its filters |
| iPad pointer and keyboard | `ShellTests`, `MoveTests` on iPad | ✅ ⌘1–⌘4, ⌘E, ⇧⌘M, ⌘F. ⌘⌫ and ⌘Z couldn't be sent by XCUITest (D63): **Owner** on a hardware keyboard |
| Download size | unsigned Release device build | ✅ 25 MB installed, 6.2 MB compressed (budget 30 MB). App Store Connect's sizes are final |
| "Data Not Collected" privacy label | manifests, policy grep | ✅ Answers in `docs/release/app-store.md` |
| One full No-AI release pass | CI's UI suite (every test forces Classic) | ✅ Passed on the SE (101 of 103 first run; the other 2 are under Open bugs) and on the iPad (108 passed, 0 failed) |

## Performance (PRD §9)
| Budget | Measured | Where | Status |
|---|---|---|---|
| Cold launch < 400 ms (iPhone 15) | 3.0 s average (Debug build, simulator spawn) | Pro Max simulator | Trend only; **Owner** on an iPhone 15 |
| 1,000-item grid at 120 fps | Completes after the decode fix; the simulator records no scroll metric | Pro Max simulator | **Owner:** Instruments Hitches on ProMotion |
| Search < 100 ms at 5,000 items | slowest keystroke 7.9 ms | Mac, release build | ✅ |
| First AI card < 2 s, scan < 8 s | — | — | **Owner** (AI iPhone, P8 signed off) |
| 500-item PDF < 20 s | `ReportRendererTests` | CI | ✅ `fiveHundredItemsRenderInBudget` asserts under 20 s and passes on the SE and the iPad (no time logged; device time is **Owner**) |
| Spotlight rebuild at 5,000 items | SPOTLIGHT_MS, off the main thread | SE simulator | ✅ `spotlightEntitiesAt5000ItemsBuildQuickly` passes: 3 s on the SE, 2 s on the iPad (test time) |
| Download size < 30 MB | 6.2 MB compressed, 25 MB installed | Release device build | ✅ |

## Smoke suite
| ID | iPhone SE | 13-inch iPad | Note |
|---|---|---|---|
| S1–S12 | ✅ 101 passed, 2 flaky failures (below), 18 skipped; rerun alone 3×, both pass | ✅ 108 passed, 0 failed, 13 skipped | Every earlier phase's suite, in `scripts/ci.sh` |
| S13 | ✅ partly | — | S3 and S5 flows plus their audits pass. **Owner:** the real VoiceOver-only run on a device |

## Accessibility (screens touched)
- **S-10 and S-12:**
  - In the P13 audit on the SE and the 13-inch iPad.
  - Rows stack at accessibility sizes.
  - Swipe actions are also in the context menu and VoiceOver's actions.
- **The Accessibility Nutrition Label answers** are in `docs/release/app-store.md` §3. Change a row to "No" if the owner's device pass finds a common task that doesn't work.

## No-AI check
Every UI test launches with Force Classic unless it fakes AI. P13 changed no router code.

## Open bugs
No crash or data-loss bugs. Two UI tests failed in the SE's full run. Each passed alone 3 times, and both passed in the iPad's full run. They have not been fixed:
- `CaptureTests.testAIScanFailureFallsBackToTagging`
- `FindTests.testMoveFromAResultAndUndo`

On PR #43's CI run (SE) both of these passed and a different test failed: `testAIScreensPassTheAccessibilityAudit` tapped the Settings tab while the capture sheet was still dismissing, so the tap was lost and the app stayed on Home. All Settings tab taps in the audit tests now go through `openSettings()`, which retries until Settings is up. It passes on the SE and the 13-inch iPad.

Treat the two above as flaky until a second full run on a clean simulator says otherwise.

## Owner checks (needed for Gate 4)
1. **Gate 3 (D60):**
   - App Store Connect: product, agreements, sandbox tester.
   - CloudKit Production and Push (D59).
   - The hosted privacy and support pages.
   - Device purchases and the two-device sync script.
2. **P12's device checks:** widgets and their styles, before the first unlock, controls and the Action button, Spotlight, Siri, Face ID and Touch ID.
3. **Archive and upload** per `docs/release/app-store.md` §6.
4. **TestFlight:** at least 30 testers (at least 10 without Apple Intelligence, at least 5 on iPads) and the 5-person first-run check. Watch crash-free until it's at least 99.8%.
5. **Device budgets:** launch on an iPhone 15, Hitches on ProMotion, the 500-item PDF on an iPhone 15.
6. **Hardware keyboard:** ⌘⌫ and ⌘Z.
7. **Accessibility settings:**
   - Liquid Glass slider at both ends.
   - Reduce Transparency, Increase Contrast and Voice Control.
   - S13 with VoiceOver only.
8. **First Capture tap** right after launch (P8-1).
9. **App Store screenshots** with real photos: `TEST_RUNNER_SHOWCASE_PHOTOS=<folder>`, with files named after the seeded items (§5).
10. **Name and trademark,** launch countries and currencies (PRD §10).
