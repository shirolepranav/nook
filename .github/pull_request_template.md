## What & why
<!-- One or two sentences. Link the issue. -->

**Phase:** P<N> · **Traces:** <!-- F#, US#, D#, screen § -->

## Screenshots / video (UI changes)
<!-- Light · Dark · AX3. Add compact + regular/Duo if the layout changed. -->

## Definition of Done
- [ ] In scope for the current phase ([roadmap](../docs/02_Roadmap.md)); nothing from a later phase
- [ ] Unit tests added or updated; a UI test for the primary flow if one changed
- [ ] Tokens only (no color/size/motion literals outside NookUI); glass only on controls
- [ ] Accessibility: VoiceOver labels and actions, Dynamic Type to AX5, Reduce Motion, 44-pt targets. No new Accessibility Inspector warnings
- [ ] Works at compact and regular width (and on Duo if the layout changed); no `UIScreen.main`
- [ ] Router touched? Classic path tested and a "No AI" check done; no AI mentioned in user-facing errors
- [ ] Data model touched? CloudKit-safe rules followed, schema version and migration test added
- [ ] Privacy: no network calls, no user content in logs, Private items excluded from Spotlight, Siri and widgets
- [ ] Docs updated if behavior changed; `docs/decisions.md` entry added for any new choice
- [ ] `[Verify in SDK]` APIs used? Verified in Xcode 27.1 and noted in decisions.md

## Phase-closing PRs only
<!-- Paste the QA report from docs/05_Testing_and_QA.md §9, including the smoke-suite table. -->

🤖 Generated with [Claude Code](https://claude.com/claude-code) <!-- remove if not agent-authored -->
