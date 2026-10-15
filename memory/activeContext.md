# Active Context

_Last updated: 2026-10-15_

## Branch

- `cursor/qualifiers-53df`

## Current focus

Qualifiers implemented (Phases 1–4): `BeanKey`, `@Qualifier`, `named:` on `@Bean`/`@Service`, generator + tests green on Linux.

## Just changed

- `specs/qualifiers/SPEC.md`
- `Qualifier.swift`, macro overloads, `BeanKey`, scanner/resolver/validator/codegen
- `GeneratorQualifierTests` + macro/runtime tests
- README / CHANGELOG / compile-time-di cross-links

## Next steps

1. PR review / merge
2. Optional: example-app demo with two `JSONDecoder`s on macOS
