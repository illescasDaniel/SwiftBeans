# Active Context

_Last updated: 2026-10-14_

## Branch

- `main`

## Current focus

Phase 1 SPEC approved. Ready for Phase 2 (architecture / contracts). No implementation code yet.

## Just changed

- Approved [`specs/compile-time-di/SPEC.md`](../specs/compile-time-di/SPEC.md)
- Root = `@ApplicationContext`; `@Service` attribute-only; YAML multi-module scan; static `@Bean`
- Committing tooling + SPEC before Phase 2

## Blockers

- None

## Next steps

1. Phase 2 — Architecture: public contracts + macro vs plugin module seams; stop for approval
2. Phase 3 — Tests from BDD scenarios
3. Phase 4 — Implement macros + generator + plugin until `swift test` is green
