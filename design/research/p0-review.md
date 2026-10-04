# P0 user-flow review

P0's hallway tests were replaced by an expert review (D27). This file has that review, plus the session script to reuse when real users test the first builds and the TestFlight beta.

## 1. Prototype integrity (automated)
- **Dead links: 0.** Every `href` in `design/screens/` points to a board that exists.
- **Reachability: 100%.** All 50 screen components can be reached from **Prototype · start here** by following links.
- **The only `#` links left** are Terms and Privacy on the paywall, which are external pages in the app.
- **Token check:** `python3 design/tools/check_tokens.py` reports 0 issues (contrast, colors, spacing, type).

## 2. Cognitive walkthrough
Times are rough estimates: about 1.5 s per obvious tap, 3 s per tap that needs a decision, 5 s per short typed name, and the PRD's budgets for AI work.

| Flow | Path | Taps | Est. time | Target | Result |
|---|---|---|---|---|---|
| Onboarding | Get Started → pick rooms (4 are preselected) → Continue | 2–6 | 10–20 s | < 60 s (PRD §3) | ✅ |
| US1 with AI | Scan a room → camera soft ask → system prompt → shutter → Done → Accept All → Save | 7 | ~35 s (+ ≤ 8 s scan) | < 3 min (PRD §1) | ✅ |
| US1 by hand, 8 items | shutter → Done → per item: draw box, type 3 letters, pick a suggestion, Add → Save | ~35 | 1.5–2 min | < 2 min (F3) | ⚠️ borderline |
| US2 photo + name | Capture → Add item → shutter → Save (name suggested or picked) | 2 after opening | ~8 s | 2 taps (F2) | ✅ |
| US3 Where is…? | Find → tap field (or a suggestion) → answer card | 2 | < 5 s | answer < 100 ms (F5) | ✅ |
| US4 Move | Move → recent location | 2 | ~4 s | 2 taps (F6) | ✅ |
| US5 Report | Reports → Insurance report → Preview → Export | 4 | ~10 s + ≤ 20 s render | < 20 s for 500 items (F9) | ✅ |
| US6 Warranty | Editor → warranty length → "Reminders 30 and 7 days before" | 1 | ~3 s | reminder at 30 days (F4) | ✅ |

## 3. Findings
| # | Finding | Sev (05 §8) | Fix | Status |
|---|---|---|---|---|
| 1 | Find's placeholder ("Search or ask: Where are the passports?") is cut off on iPhone SE, so the example is lost | P2 | Placeholder is now "Search or ask anything", with a **Try asking** chip ("Where are the passports?") above Saved searches | Fixed on the canvas |
| 2 | "Scan barcode · Save the product code" suggests a product lookup, which needs the network (PRD: no network) | P2 | "Add a product code to an item" | Fixed |
| 3 | Paywall "Launch price · then $19.99" doesn't say how long the launch price lasts | P2 | "Launch price for 2 weeks, then $19.99" (D9) | Fixed |
| 4 | Scan review "Save 2 Items" when 6 are suggested: some people may think Save keeps all six | P2 | "Accept All" is in the header now. Watch for this in the first builds; if it happens, label the button "Save 2 · 4 not accepted" | Open risk, check in builds |
| 5 | Tagging 8 items by hand is near F3's 2-minute limit | P1 risk | The autocomplete list (500 common items) must show suggestions after 1 letter, and Add must keep the keyboard up for the next box. Spec it in P6 | Open, P6 |
| 6 | Item cards' VoiceOver label in Room reads "name, price" but PRD §3 asks for name, room and value | P1 (a11y) | Only a mockup label; the rule is in 03 §11. NookUI's `ItemPhotoCard` must build the label from name + breadcrumb + value (P1 test) | Open, P1 |
| 7 | Home has two prompts in the empty state (the Scan a room button and the glowing Capture) | P3 | Both lead to the same action, and the glow fades after the first save. Kept, as `01` O-02 asks | Accepted |
| 8 | Prototype limits: no camera, keyboard, haptics or real VoiceOver in the canvas player | — | Covered by D27: real-user and VoiceOver checks in the builds and TestFlight | Accepted risk |

## 4. Accessibility review (boards)
- Every screen has an **AX5** board, and grids switch to single-column lists.
- Every board was built with real `button` and `a` elements and `aria-label` on icon-only controls. Touch targets are at least 44 pt. Toggles carry `aria-pressed` and `aria-checked`. Streaming and coach text uses `role="status"`.
- **Contrast:** every token pair passes 4.5:1, and 7:1 for High Contrast (D24).
- **Not covered without people:** VoiceOver reading order, and Voice Control naming. These go to the P13 audit and TestFlight (D27).

---

## Appendix: session script for real-user tests (first builds and TestFlight)

### Setup
- **Device:** your iPhone, in Safari, signed in to claude.ai. Install the build (or the TestFlight beta). Until a build exists, the canvas prototype works too: **Prototype · start here** → **Play**.
- **Before each session:** start from the Prototype board. Each flow button takes the tester to the first screen of that flow.
- **Limits to tell testers about:** there's no camera, keyboard or haptics. Tapping the shutter "takes" a photo, and typing is pre-filled.
- **Record:** a stopwatch, plus this sheet. Screen recording is optional, with consent.

### Participants (aim for this mix)
| # | Profile |
|---|---|
| P1 | Not very techy, owns lots of stuff |
| P2 | Recently moved or is moving |
| P3 | **VoiceOver user** (if you can find one) |
| P4 | Older iPhone owner (no Apple Intelligence) |
| P5 | Anyone new to Nook |

### Script (about 15 minutes)
Say: "We're testing the design, not you. Please think out loud. If you get stuck, that's useful for us."

| Task | Prompt to read | Starts at | Success | Target |
|---|---|---|---|---|
| T1 | "You just installed Nook. Set it up for your home." | Onboarding · Start | Reaches Home with rooms | < 60 s |
| T2 | "Document what's on your kitchen shelf." | US1 · With Apple Intelligence | Taps Save on the review cards | **< 3 min** |
| T3 | "Same again, on an iPhone that can't suggest names." | US1 · Without | Tags items and saves | note the time |
| T4 | "Where is your passport?" | US3 · Start | Reads out Office → Desk → Second drawer | < 30 s |
| T5 | "You just moved it into the safe. Tell Nook." | from T4's answer card | Move, then a location (2 taps) | 2 taps |
| T6 | "Is the dishwasher still under warranty?" | Onboarding → Home, or Reports | Finds "Ends in 12 days" | < 45 s |
| T7 | "You just bought a lamp. Add it." | Home | First tap lands on Capture | time to first tap |

After the tasks:
1. For each task: "How easy was that, from 1 (very hard) to 7 (very easy)?"
2. "Describe Nook in one word."

