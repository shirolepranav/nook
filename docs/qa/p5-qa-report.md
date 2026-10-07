# P5 QA report — 2026-10-06
Builds: `p5/find`, fast-forwarded to `main` at the owner's request · Xcode 27.0 · iOS 27.0 simulators
Devices: iPhone SE (3rd gen), 13-inch iPad Pro (M5)
Runs (a reduced close, at the owner's request: no full `scripts/ci.sh`, light-mode screenshots only):
- **Build:** clean, 0 warnings.
- **NookKit:** 71 ✔ (`swift test`), 25 of them new: search ranking, typos, synonyms, filters, question parsing, `FindService` answers and saved searches, the schema.
- **Search budget (F5):** `everyKeystrokeIsUnder100msAt5000Items` on an optimized build: the slowest keystroke takes 7 ms at 5,000 items on a Mac, and an index rebuild about 75 ms. `ci.sh` now runs it with `-c release`.
- **NookUI:** the new `answerCard` snapshots in all 5 variants.
- **`FindTests` (5):** pass on the SE and on the 13-inch iPad.
- **Accessibility audits:** P1–P4's Home, Room and Move audits pass on the SE. Two fail (below); the owner chose not to pursue them.
- **Not run this phase:** the full app suite on the Pro Max and the iPad, and `ci.sh` end to end.

**Status:** In QA. The **Owner** rows need a device.

Closing P5 turned up these problems, all fixed:
- **"skis" answered with "Cast iron skillet".** Singulars were matched as prefixes ("ski…"), and 4-letter words could have a typo against the start of longer words. Singulars now match whole words only, and typos against the start of a word need 5 letters (D46).
- **Filters couldn't be reached while typing on iPhone.** The search tab hides the navigation bar while its field is focused. Filters is now also a chip in the list (D47).
- **Save Search sometimes did nothing.** The name prompt was asked for while the filters sheet was still closing, and iOS dropped it. It now waits for the sheet to close.
- **Rooms and spots** are registered once per navigation stack, at its root, so Find can push them.

## Acceptance (roadmap P5)
- [x] **Results in under 100 ms for 5,000 items (F5).** 7 ms on an optimized build (above). **Owner:** type in Find with `-uiTestingStore items5k` on an iPhone 15.
- [x] **Find tab (F-01) with the system search role.** Before typing: Try asking, saved searches, quick filters, recent searches. Each section hides when empty.
- [x] **Instant results (F-02) with typo tolerance and synonyms.** `testATypoAnswersWithLocationAndLastConfirmed` ("skilet"), `testQuestionsAnswerFromRecords` ("fob" finds "Spare car key"). Sections: Items, Rooms and spots, Containers; each row has Move.
- [x] **Answer cards (F-03):** location, lent, packed, room contents and quantity, from records only (`FindServiceTests`, `testQuestionsAnswerFromRecords`). No record, no card.
- [x] **Filters (F-05),** including last seen. Room, category, tags, value (home currency), warranty, lent out. Active filters are removable chips. `testFilterSaveRenameAndDeleteASearch`.
- [x] **Saved searches (F-06):** save, run, rename and delete by swipe, reorder. Same test, plus `savedSearchesKeepOrderAndFilters`.
- [x] **Receipt text included in search.** `receiptsDetailsAndPlacesAreSearched`; the `lived` espresso machine's receipt reads "Order 7781".

## Phase QA
| Case | Device | Result |
|---|---|---|
| Misspellings | unit, SE, iPad | ✅ "pasport", "pssport", "skilet"; 3-letter words stay exact |
| Partial words | unit | ✅ Prefixes ("caf" → Café press); a typo in a partial word from 5 letters ("paspo") |
| Serial numbers | unit | ✅ "SN-4471" and "sn4471ab" both find "SN-4471-AB" |
| Accents and diacritics | unit | ✅ "CAFE" finds "Café press"; emoji and Arabic names match |
| No results | SE, iPad | ✅ "Nothing called “skis” yet." with Add, which opens quick add with the name filled in |
| Private items appearing as hidden | unit, SE, iPad | ✅ "Private item · Unlock to see it", no name or photo, never an answer card. Opens on tap until P12 (D46) |

## Smoke suite
| ID | Device | Result | Note |
|----|--------|--------|------|
| S1–S4 | iPhone SE (sim) | ✅ | Last full run at P4's close; the P5 changes to Home, Room and the shell are covered by the P1–P4 audits that ran here |
| S5 | iPhone SE (sim) | ✅ | `testATypoAnswersWithLocationAndLastConfirmed` |
| S5 | 13-inch iPad (sim) | ✅ | Same test |
| S5 | Real iPhone | **Owner** | Typo search, the answer card, and the success haptic on a move from it |

## Accessibility (screens touched: F-01, F-02, F-03, F-05, F-06, I-01 tags)
- [ ] **Accessibility audit:** `testFindScreensPassTheAccessibilityAudit` fails on one Dynamic Type warning: the footer "Also searched receipts, serials and notes." `testItemScreensPassTheAccessibilityAudit` fails with "Potentially inaccessible text" on I-01 since the `lived` seed gave the espresso machine a tag; it's the P3 tag chips. **The owner chose not to pursue these.**
- [x] **VoiceOver labels:** result rows read "name, room, path"; the masked row reads "Private item. Unlock to see it"; Move is an action on every row; each tag reads "Tag: Coffee"; the answer card is a container named "Answer".
- [x] **Reduce Motion:** results swap with `NookMotion.fade`; moves use `settle`.
- [ ] **Owner:** VoiceOver through S5 on a device.
- [x] **Screenshots:** light only on the SE and the iPad (owner's choice), from `ScreenshotTests.testP5Screens` (opt-in).

| Screen | iPhone SE | 13-inch iPad (portrait) |
|---|---|---|
| F-01 Find | [light](p5/SE-f-01-find.jpg) | [light](p5/iPad-f-01-find.jpg) |
| F-05 Filters | [light](p5/SE-f-05-filters.jpg) | [light](p5/iPad-f-05-filters.jpg) |
| F-02 Filtered results | [light](p5/SE-f-02-filtered-results.jpg) | [light](p5/iPad-f-02-filtered-results.jpg) |
| F-02 Results, private masked | [light](p5/SE-f-02-results-private-masked.jpg) | [light](p5/iPad-f-02-results-private-masked.jpg) |
| F-03 Answer, typo | [light](p5/SE-f-03-answer-typo.jpg) | [light](p5/iPad-f-03-answer-typo.jpg) |
| F-03 Lent | [light](p5/SE-f-03-lent.jpg) | [light](p5/iPad-f-03-lent.jpg) |
| F-03 Packed | [light](p5/SE-f-03-packed.jpg) | [light](p5/iPad-f-03-packed.jpg) |
| F-03 Contents | [light](p5/SE-f-03-contents.jpg) | [light](p5/iPad-f-03-contents.jpg) |
| F-03 Quantity | [light](p5/SE-f-03-quantity.jpg) | [light](p5/iPad-f-03-quantity.jpg) |
| F-02 No results | [light](p5/SE-f-02-no-results.jpg) | [light](p5/iPad-f-02-no-results.jpg) |

## No-AI check
n/a: P5 is the Classic path. Questions are read by `FindQuestion` and answered from records; the router joins in P8 and the AI answers in P9.

## Open bugs
| ID | Sev | Summary |
|----|-----|---------|
| — | P3 | The two accessibility audits above. |
| — | P3 | "Try asking" uses the latest item's name as typed, so it can read oddly ("Where’s my AA batteries?"). |
| — | P3 | The answer card's "Found It Here Instead" label wraps to two lines on the iPhone SE beside Move. |
