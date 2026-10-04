# Design mockups

The approved visual direction for Nook. They're pulled from the Claude Design canvas
"Nook — App screens": https://claude.ai/artifact/MYsu1xGJDwiuHKrzksKHMU

| File | Screen |
|---|---|
| `screens/Main.dc.html` | Home (light) |
| `screens/HomeDark.dc.html` | Home (dark) |
| `screens/Room.dc.html` | Room · Kitchen |
| `screens/ItemDetail.dc.html` | Item detail |
| `screens/Find.dc.html` | Find · Answer card |
| `screens/ScanReview.dc.html` | Scan review |
| `screens/Paywall.dc.html` | Paywall |

**How to use them**
- They're 390×844 HTML mockups. Read the markup for exact colors, type sizes, radii, spacing and layout.
- **Visual detail:** the mockups win. **Behavior, states and a11y:** `docs/01_Pages_UI_Interactions.md` wins.
- Translate every value into a `NookUI` token. Never copy a hex or px literal into Swift. If a value has no token, add the token (and update `docs/03_Design_System.md`) or flag the mismatch.
- The HTML stands in for native controls. The tab bar and floating buttons map to the system Liquid Glass tab bar and buttons. Don't recreate them by hand.

**Updating:** after you change the canvas, re-pull it into `design/screens/` in the same PR (ask Claude to "re-sync the design mockups").
