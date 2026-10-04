# Design mockups

The approved visual direction for Nook. They're pulled from the Claude Design canvas
"Nook — App screens": https://claude.ai/artifact/MYsu1xGJDwiuHKrzksKHMU

Each screen is one **component board** (iPhone SE, 375×667, light) with tweaks for `dark`, `accent`, `ax5`, `device` (`se`/`pro`/`max`) and `state`. The **variant boards** (`<Component>-<variant>.dc.html`) import the component with those tweaks set, so every variant stays in sync with its component. All colors, type and spacing come from the CSS token block at the top of each file (`docs/03_Design_System.md`).

### Coverage (P0)
| ID | Component | Light | Dark | States | Sizes | AX5 |
|---|---|---|---|---|---|---|
| L-01 Launch | `L01Launch` | ✓ | ✓ | — | SE | — (no text) |
| O-01 Welcome | `O01Welcome` | ✓ | ✓ | — | SE | ✓ |
| O-02 Pick your rooms | `O02Rooms` | ✓ | ✓ | — | SE | ✓ |
| H-01 Home + shell | `Main` | ✓ | ✓ | populated, empty, loading, error (all light + dark) | SE, 6.3 in, 6.9 in | ✓ |
| H-01/H-02 regular width | `HomeRegular` | ✓ | ✓ | populated | 6.9 in landscape (956×440) | — |
| H-02 Room | `Room` | ✓ | ✓ | populated, empty (light + dark) | SE, 6.3 in, 6.9 in | ✓ |
| H-03 Spot / container | `H03Spot` | ✓ | ✓ | spot, container (light + dark) | SE | ✓ |
| H-04 Room editor | `H04RoomEditor` | ✓ | ✓ | edit, delete with items (light + dark) | SE | ✓ |
| H-05 Spot / container editor | `H05SpotEditor` | ✓ | ✓ | spot, container | SE | ✓ |
| H-06 QR box label | `H06QRLabel` | ✓ | ✓ | — | SE | ✓ |
| H-07 Arrange rooms | `H07Arrange` | ✓ | ✓ | — | SE | ✓ |
| C-01 Capture menu | `C01CaptureMenu` | ✓ | ✓ | default, from a room | SE | ✓ |
| C-02 Room scan camera | `C02RoomScan` | ✓ | ✓ | first-scan coach, 2 photos taken, camera soft ask, camera off (light + dark) | SE, 6.3 in, 6.9 in | ✓ |
| C-03 Scan review (AI) | `ScanReview` | ✓ | ✓ | complete, streaming in (light + dark) | SE, 6.3 in, 6.9 in | ✓ |
| C-03 regular width | `ScanReviewRegular` | ✓ | ✓ | photo left, cards right | 6.9 in landscape | — |
| C-04 Manual tagging (Classic) | `C04ManualTag` | ✓ | ✓ | naming, tagged list (light + dark) | SE | ✓ |
| C-05 Quick add | `C05QuickAdd` | ✓ | ✓ | — | SE | ✓ |
| C-06 Receipt scan | `C06Receipt` | ✓ | ✓ | tap to fill (Classic), suggested (AI) | SE | ✓ |
| C-07 Barcode scanner | `C07Barcode` | ✓ | ✓ | aiming, barcode added | SE | ✓ |
| C-08 Serial sticker reader | `C08Serial` | ✓ | ✓ | pick a line (Classic), suggested (AI) | SE | ✓ |
| I-01 Item detail | `ItemDetail` | ✓ | ✓ | default, lent, private (unlocked), private (locked) | SE, 6.3 in, 6.9 in | ✓ |
| I-01 regular width | `ItemDetailRegular` | ✓ | ✓ | detail beside the grid | 6.9 in landscape | — |
| I-02 Item editor | `I02Editor` | ✓ | ✓ | new, suggested fields, warranty warning, discard changes | SE | ✓ |
| I-03 Photo viewer | `I03Photo` | ✓ | ✓ | — | SE | ✓ |
| I-04 Move picker | `I04Move` | ✓ | ✓ | one item, 3 items, moved with Undo | SE | ✓ |
| I-05 Location history | `I05History` | ✓ | ✓ | — | SE | ✓ |
| I-06 Lend sheet | `I06Lend` | ✓ | ✓ | — | SE | ✓ |
| I-07 Receipt viewer | `I07Receipt` | ✓ | ✓ | — | SE | ✓ |
| I-08 Multi-select | `I08Select` | ✓ | ✓ | 3 selected | SE | ✓ |
| F-01 Find (+ F-06 saved searches) | `F01Find` | ✓ | ✓ | before typing, saved search swiped | SE, 6.3 in, 6.9 in | ✓ |
| F-02 Results | `F01Find` | ✓ | ✓ | results (typo + private item), no results | SE | via F-01 |
| F-03 Answer card | `F01Find` | ✓ | ✓ | location, lent, packed, room contents, quantity | SE, 6.3 in, 6.9 in | ✓ |
| F-01/F-03 regular width | `FindRegular` | ✓ | ✓ | results beside the answer | 6.9 in landscape | — |
| F-04 Move confirmation | `F01Find` | ✓ | ✓ | — | SE | ✓ |
| F-05 Filters | `F05Filters` | ✓ | ✓ | — | SE | ✓ |

**Not yet rebased** (later P0 batches; still 390×844 and partly untokenized): `Paywall` (P-01).

Camera feeds and photos are token-colored stand-ins (wall, shelf, objects); the app shows the user's photo. Illustrations are labelled placeholders (`[ILLUSTRATION: …]`) until the illustrations PR.

**How to use them**
- Read the markup for exact colors, type sizes, radii, spacing and layout.
- **Visual detail:** the mockups win. **Behavior, states and a11y:** `docs/01_Pages_UI_Interactions.md` wins.
- Translate every value into a `NookUI` token. Never copy a hex or px literal into Swift. If a value has no token, add the token (and update `docs/03_Design_System.md`) or flag the mismatch.
- The HTML stands in for native controls. The tab bar and floating buttons map to the system Liquid Glass tab bar and buttons. Don't recreate them by hand.

**Updating:** after you change the canvas, re-pull it into `design/screens/` in the same PR (ask Claude to "re-sync the design mockups"), then run `python3 design/tools/check_tokens.py`.
