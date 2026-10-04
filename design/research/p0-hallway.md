# P0 hallway tests — kit and results

Roadmap P0 QA: **5 hallway tests of the prototype, including one person using VoiceOver if possible. Target: a new user "documents" a room in the prototype in under 3 minutes.** These sessions also decide the Capture button placement (D2).

## Setup
- **Device:** your iPhone, in Safari, signed in to claude.ai. Open the [Nook canvas](https://claude.ai/artifact/MYsu1xGJDwiuHKrzksKHMU), go to **Prototype · start here**, press **Play**, and switch to full window.
- **Before each session:** start from the Prototype board. Each flow button takes the tester to the first screen of that flow.
- **Limits to tell testers about:** there's no camera, keyboard or haptics. Tapping the shutter "takes" a photo, and typing is pre-filled.
- **Record:** a stopwatch, plus this sheet. Screen recording is optional, with consent.

## Participants (aim for this mix)
| # | Profile | Capture order |
|---|---|---|
| P1 | Not very techy, owns lots of stuff | A then B |
| P2 | Recently moved or is moving | B then A |
| P3 | **VoiceOver user** (if you can find one) | A then B |
| P4 | Older iPhone owner (no Apple Intelligence) | B then A |
| P5 | Anyone new to Nook | A then B |

## Script (about 15 minutes)
Say: "We're testing the design, not you. Please think out loud. If you get stuck, that's useful for us."

| Task | Prompt to read | Starts at | Success | Target |
|---|---|---|---|---|
| T1 | "You just installed Nook. Set it up for your home." | Onboarding · Start | Reaches Home with rooms | < 60 s |
| T2 | "Document what's on your kitchen shelf." | US1 · With Apple Intelligence | Taps Save on the review cards | **< 3 min** |
| T3 | "Same again, on an iPhone that can't suggest names." | US1 · Without | Tags items and saves | note the time |
| T4 | "Where is your passport?" | US3 · Start | Reads out Office → Desk → Second drawer | < 30 s |
| T5 | "You just moved it into the safe. Tell Nook." | from T4's answer card | Move, then a location (2 taps) | 2 taps |
| T6 | "Is the dishwasher still under warranty?" | Onboarding → Home, or Reports | Finds "Ends in 12 days" | < 45 s |
| T7 | "You just bought a lamp. Add it." | CAPTURE A/B, in the order above | First tap lands on Capture | time to first tap |

After the tasks:
1. For each task: "How easy was that, from 1 (very hard) to 7 (very easy)?"
2. For Capture: "Which way of adding things felt more natural, A or B? Why?"
3. "Describe Nook in one word."

## Results
| P | T1 | T2 | T3 | T4 | T5 (taps) | T6 | T7 A first tap | T7 B first tap | Prefers | Notes / quotes |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | | | | | | | | | | |
| P2 | | | | | | | | | | |
| P3 | | | | | | | | | | |
| P4 | | | | | | | | | | |
| P5 | | | | | | | | | | |
| **Median** | | | | | | | | | | |

**Success codes:** ✓ unaided · ◐ needed a hint · ✗ gave up.

## Decision rule for Capture placement (D2)
- Pick the placement with the **faster median time to first tap** in T7 and **fewer misses** (taps somewhere else first).
- If they're within 1 s and tied on misses, choose **A, the floating button**. It's what the PRD describes, and it doesn't take space from the content.
- Log the result as a new decision entry, then delete the losing variant boards (`Main-accessory`, `Main-empty-accessory`).

## Findings → fixes
| Finding | Severity (05 §8) | Screen | Fix | Done in |
|---|---|---|---|---|
| | | | | |
