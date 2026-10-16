# Active Context

_Last updated: 2026-10-16_

## Branch

- `feature/improvements` (local only — not pushed; individual draft PRs #1–#7 left open)

## Current focus

Stack of all seven draft PRs is merged and **`swift test` is green (201 tests / 19 suites)**. Cross-feature seams for `BeanKey` fixed during integration. Ready for deeper combined validation (example app) when asked.

## Just changed

- Merged in order: #3 → #4 → #2 → #7 → #6 → #5 → #1
- Integration compile fixes: `GraphDump` / `GraphValidator` / `ProviderResolver` for stacked `BeanKey` + factories + collections
- Plugin: `--request` + `--graph-markdown` / `--graph-dot`

## Next steps

1. Optional: run example app macOS tests / iOS Simulator build on this branch
2. Push `feature/improvements` only when asked
3. Do not merge to `main`; do not close the seven PRs
4. Remaining backlog: child-contexts Phase 2+, example adoption of new features, nested-`any` array accessor gap
