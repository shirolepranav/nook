---
name: ai-capability
description: Add or change a Nook capability that has an AI path and a manual/classic path — room scan, item fill, receipt reading, serial reading, "Where is…?" answers, value estimates, report summaries. Use for any work in Packages/NookAI, the CapabilityRouter, Foundation Models, Vision/VisionKit, or evaluations.
---

# AI capability (router + both engines)

The product rule: **nothing requires AI.** Every capability has two engines behind one router, and they return one shared result type. The user never sees an AI error; the manual path simply appears. Read `docs/04_Architecture.md` §2 (router contract) and §6 (Find) before changing anything.

## 1. Define the contract first
- Write or extend the shared result type in `Packages/NookAI/Sources/NookAI/Types/`. It's `Sendable`, and `@Generable` if the model fills it (use `@Guide` descriptions like `DetectedItem` in PRD §8).
- AI-only extras (a value estimate, a room summary) are **optional fields**. The classic engine leaves them `nil`, and the UI hides them.
- Add the method to `CapabilityEngine`. Streaming work returns `AsyncThrowingStream`.

## 2. Classic engine first (every iPhone)
- Implement it in `ClassicEngine` using Vision (`RecognizeTextRequest`), VisionKit (`DataScannerViewController`, document camera), the name list in `common-items.json`, the synonyms in `synonyms.json`, and `FindQuerying`.
- The classic path usually returns *candidates* for the user to tap: OCR lines, highlighted prices and dates, name suggestions. The screen spec in `01` says what the manual UI does with them.
- It must meet the PRD acceptance criteria on its own (for example, F3 manual: 8 items in under 2 min).

## 3. AI engine (Apple Intelligence iPhones)
- Only `NookAI` imports `FoundationModels`. Use a `LanguageModelSession` with clear instructions, structured output (`@Generable`), and **tool calling** for anything that needs app data (`FindQuerying`) or OCR and barcodes.
- Image input: resize to 1,536 px on the long side first. Confirm the Foundation Models image-input API in the Xcode 27.1 SDK [Verify in SDK] and log the result in `docs/decisions.md`.
- **Timeout:** 20 s per photo or request. Any failure (timeout, guardrail, busy model, unsupported language, a thrown error) makes the router fall back to the classic engine **for that unit of work only**, with the input preserved.
- **Stream** results so the first card appears in under 2 s.
- **Grounding:**
  - Answers are phrased only from records returned by the tools.
  - If no record matches, return `.notFound`. Never guess a location.
  - Move statements return a `proposedMove`. **Engines never write.** Writes happen only in `LocationService` after the user confirms.
- Private items are excluded from tool results unless the app is unlocked.

## 4. Route it
- Services call `await router.engine().<method>(…)`. Availability is checked **per task**.
- Never branch on device model. Use availability only.
- Respect the debug **Force classic engine** toggle.

## 5. Tests (all required)
- **Router:** a fake availability returning `.ai` → the AI engine is used. `.classic` → the classic engine. AI throws or times out → the classic fallback, with the input preserved and no error surfaced.
- **Classic engine:** unit tests on fixtures (`Fixtures/receipts`, `Fixtures/shelf`).
- **AI engine:** use an evaluation case in `NookAI/Evaluations` (`Fixtures/eval`) and follow `docs/05_Testing_and_QA.md` §4. For "Where is…?", include questions about **items that don't exist** (the expected result is not-found) and move statements (a proposal only).
- **UI:** the screen shows identical structure for both engines. Run it once with Force classic on.

## 6. Before the PR
- [ ] "No AI" check (05 §6) on the flows you touched: no AI wording anywhere, and no errors.
- [ ] Performance signposts added for the budgets (first card < 2 s, room scan < 8 s).
- [ ] Evaluation numbers pasted into the PR (recall and precision, or question accuracy).
- [ ] AI-filled fields are shown as "Suggested" and value ranges as "Estimate" (03 §8.5, §12).
