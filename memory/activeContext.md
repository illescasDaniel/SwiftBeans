# Active Context

_Last updated: 2026-10-14_

## Branch

- `main`

## Current focus

None — `AppContextProtocol` generation + example `FakeAppContext` / Previews landed.

## Just changed

- Generator emits `{Context}Protocol` + conformance (`BeanCodeGenerator` / `Naming.protocolName`)
- Example: deleted `AppContaining`; added `FakeAppContext`; `#Preview` on all views; tests use fakes
- SPEC/ARCHITECTURE updated for context protocol BDD

## Next steps

1. Optional: push `main` when ready
2. Docs / README usage polish for compile-time DI (include HTTIES `@Bean` + `AppContextProtocol` / `FakeAppContext` pattern)
