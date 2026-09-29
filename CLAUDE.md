# CLAUDE.md — Nook

Nook is a native iPhone app (Swift 6, SwiftUI, iOS 27.0+) that catalogs everything you own **and where it is**. You photograph a room and the app lists the items. It reads receipts and serials, answers "Where is my…?", tracks warranties and loans, and exports an insurance report. **It is private and on-device, with no server and no account.** It is a one-time $19.99 Pro unlock. A small team plus Claude agents build it in phases.

## Principles (in priority order: when two conflict, the higher one wins)
1. **Design and UX first.** It should feel like a first-party Apple app, only warmer. If a feature isn't delightful yet, it waits.
2. **Nothing requires AI.** Every AI path has a fast manual path on every iPhone.
3. **Private by default.** Data and AI stay on the device. No accounts, analytics or network calls (except StoreKit and iCloud for Pro).
4. **Fast to value.** A new user documents their first room in under 3 minutes.
5. **Pay once.** No subscriptions, no ads.

## Read before you work
| If you're… | Read |
|---|---|
| Doing anything | This file, then the current phase in `docs/02_Roadmap.md` |
| Checking scope or requirements (F1–F11, US1–US6) | `docs/00_PRD.md` — **the source of truth** |
| Resolving a conflict or an open choice | `docs/decisions.md` (D1…) |
| Building UI | `docs/01_Screens_and_Interactions.md` + `docs/03_Design_System.md` |
| Writing services, data or AI code | `docs/04_Architecture.md` |
| Testing or closing a phase | `docs/05_Testing_and_QA.md` |

**Precedence:** `00_PRD.md` > `decisions.md` > other docs > code comments. If docs disagree, don't guess. Flag it, and propose a new decision entry in your PR.

## Hard rules (a PR that breaks one is rejected)
- **The router is the only path to AI.** Only `Packages/NookAI` imports `FoundationModels`/`Vision`. Services ask the `CapabilityRouter`. Both engines return the same types. AI failures fall back silently to the manual flow. **No user-facing text ever mentions AI in errors.**
- **AI never writes and never invents.** Answers come from database records only. A move proposed by AI or Siri needs the user's tap. All location writes go through `LocationService.move(items:to:source:)`.
- **No network, no third-party runtime dependencies.** StoreKit and CloudKit are the only exceptions.
- **SwiftData stays CloudKit-safe:**
  - every attribute optional or defaulted
  - every relationship optional with an inverse
  - no `.unique`, no `.deny`, no ordered relationships
  - identity is an app-owned `id: UUID`
  - blobs live on disk, not in the database
- **Size classes only.** No `UIScreen.main`, no device or idiom branching. Every screen works compact, regular and on iPhone Duo (fold, half-fold, Split View).
- **Glass for controls, paper for content.** Never put `.glassEffect()` on cards, rows, photos or toasts.
- **Tokens only.** No color, font size, spacing, radius, motion or haptic literals outside `NookUI`.
- **Accessibility is part of "done":** VoiceOver labels (name, room, value), custom actions, Dynamic Type to AX5 (grids become lists), Reduce Motion, 44-pt targets, 4.5:1 contrast. Every action works without the camera and without AI.
- **Private items** never appear in Spotlight, Siri, widgets or logs. Never log user content (use `privacy: .private`).
- **Free-tier limits** (25 items, 3 reminders, export and sync gated) are enforced in `EntitlementStore`, never in views. Never lock away data the user already entered.
- **Reminders** go through the rolling scheduler, which respects the system's cap of 64 pending notifications (D13).
- **Unverified APIs.** Anything tagged `[Verify in SDK]` (and any iOS 27 API you're unsure of) must be confirmed against the Xcode 27.1 SDK before you use it. Record the finding in `decisions.md`. Your training data may predate iOS 27.

## Working in phases
- Work **only inside the current phase's scope** (`docs/02_Roadmap.md`). Scope that belongs to a later phase goes into an issue, not the code. Use the `phase-work` skill.
- Branch as `p<N>/<short-task>`, open a PR into `main`, and keep PRs small (about 400 lines of diff or less, excluding fixtures and snapshots).
- Every PR follows the checklist in `.github/pull_request_template.md`.
- When behavior changes, update the relevant doc in the same PR. When you make a new product or technical choice, add a `D#` entry.
- A phase closes with its QA report and the cumulative smoke suite (`qa-regression` skill). Update the phase's **Status** line in the roadmap.
- **Gates** (G1–G4) are team go/no-go reviews. Never start work from the next milestone before its gate passes.

## Project layout
```
Nook/            app target: App/, Features/<Feature>/, Intents/, Resources/
NookWidgets/     widgets + controls extension
Packages/NookKit models, store, services, search, reminders, backup, entitlements
Packages/NookAI  CapabilityRouter, AIEngine, ClassicEngine, shared result types, evaluations
Packages/NookUI  design tokens, components, gallery
Fixtures/        receipts, test shelf, eval photos, seeds, golden files
docs/            PRD, screens, roadmap, design system, architecture, QA, decisions
```
(The Xcode project is created in P0. Until then this layout is the target.)

## Commands
> TBD in P0. Fill these in when the Xcode project and CI exist.
```bash
# Build:      xcodebuild -scheme Nook -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)' build
# Unit tests: swift test --package-path Packages/NookKit   (and NookAI, NookUI)
# App tests:  xcodebuild -scheme Nook -destination '…' test
# Lint:       swiftlint && swiftformat --lint .
```

## Skills (in `.claude/skills/`)
| Skill | Use when |
|---|---|
| `phase-work` | Starting or continuing any roadmap phase or task |
| `build-screen` | Creating or changing a SwiftUI screen or component |
| `ai-capability` | Adding or changing anything routed through the CapabilityRouter (AI + classic) |
| `data-model-change` | Any SwiftData model, schema or migration change |
| `qa-regression` | Closing a phase or PR: phase QA, smoke suite, a11y, No-AI pass, QA report |

## Style
- Match the surrounding code. Keep it boring and readable, with no speculative abstractions.
- Comments explain *why* and cite IDs (`// F6: 2-tap move`, `// D13`).
- User-facing copy is warm, plain and short ("Saved to Kitchen."), and lives in `Localizable.xcstrings`.
