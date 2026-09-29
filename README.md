# Nook

**Everything you own, and exactly where it is. Pay once.**

Nook is an iPhone app for your home inventory. Photograph a room and Nook lists what's in it. It reads your receipts and serial numbers, remembers where each thing lives ("Where are the passports?"), reminds you before warranties end, tracks what you've lent out, and produces an insurance-ready report in one tap.

- **Native:** Swift 6 and SwiftUI on iOS 27, designed for Liquid Glass, and adapts to every iPhone from the SE to the iPhone Duo.
- **Private:** all data and all AI stay on your iPhone, with no account and no server. Pro users get optional iCloud sync.
- **AI optional:** Apple Intelligence makes it faster, and every feature works without it.
- **Pay once:** free for 25 items, then a one-time Nook Pro unlock.

> Status: **pre-development.** Phase P0 (Foundations) and P1 (Design system) start 2026-09-28. The target launch is early January 2027.

## Docs
| Doc | What's in it |
|---|---|
| [docs/00_PRD.md](docs/00_PRD.md) | Product requirements + technical spec (**source of truth**) |
| [docs/decisions.md](docs/decisions.md) | Decision log (D1…): resolved conflicts and choices |
| [docs/01_Screens_and_Interactions.md](docs/01_Screens_and_Interactions.md) | Every screen, state and interaction |
| [docs/02_Roadmap.md](docs/02_Roadmap.md) | Milestones, gates, phases P0–P11, the smoke suite |
| [docs/03_Design_System.md](docs/03_Design_System.md) | "Warm Linen" tokens, components, motion, haptics, a11y |
| [docs/04_Architecture.md](docs/04_Architecture.md) | Capability router, packages, data model, platform rules |
| [docs/05_Testing_and_QA.md](docs/05_Testing_and_QA.md) | Test layers, CI, device matrix, AI evals, bug severity |
| [CLAUDE.md](CLAUDE.md) | Rules and entry point for AI agents (humans should read it too) |

## How we work
1. Pick up an issue from the **current phase** milestone. The phases are in [the roadmap](docs/02_Roadmap.md).
2. Branch `p<N>/<short-task>`, then open a small PR into `main` using the PR template's Definition-of-Done checklist.
3. Each phase closes with its QA report and the cumulative smoke suite. Each milestone closes with a team gate review (G1–G4).
4. Changing scope or making a new choice? Update the doc in the same PR and add an entry to `docs/decisions.md`.

Claude agents follow the same process, guided by [CLAUDE.md](CLAUDE.md) and the skills in [.claude/skills/](.claude/skills/).

## Requirements
- Xcode 27.1 (iOS 27.1 SDK); the deployment target is iOS 27.0
- For AI features: an Apple Intelligence iPhone (iPhone 15 Pro or newer). Everything else runs on any iOS 27 iPhone and in the simulator.
