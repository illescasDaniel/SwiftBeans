# Spec: Inter-Bean Call Diagnostic

## Metadata

| Field | Value |
|-------|-------|
| Feature | `inter-bean-call-diagnostic` |
| Status | Draft (Phase 1) — 2026-10-15; implemented in the same branch because the task fixed the scope up front |
| Extends | [`specs/compile-time-di/SPEC.md`](../compile-time-di/SPEC.md) (Generator rules → Diagnostics) |
| Public API | None. No new macros, no runtime changes; only a new generator diagnostic |

## Goal

In Spring, a `@Configuration` class is proxied, so `repo()` calling `database()` returns the shared singleton. SwiftBeans has no proxies: `@Bean` methods are `static`, and the generated context shares singletons only because dependencies arrive as **parameters**. A `@Bean` body that calls another `@Bean` directly (`AppConfiguration.database()`) therefore silently runs the factory again and creates a second instance outside the context's scope handling.

This feature adds the cheap first step: a **build warning** at the direct call that suggests taking the dependency as a parameter.

## Behavior

### Rules

1. After scanning, the generator analyzes the body of every `@Bean` function in a `@Configuration` type (or an extension of one), and the body of every initializer of an `@Service` type (declared in the type or in an extension).
2. A call is a **direct bean call** when the callee resolves to a known `@Bean` factory (a `@Bean` function in a `@Configuration` type or extension of one, in any scanned file). A call resolves in these forms:
	- `TypeName.beanName(...)`, where `TypeName` is the bean's configuration type spelled exactly as its qualified name, or by a trailing qualified suffix (`Config.beanName()` for `Outer.Config`).
	- `Self.beanName(...)` and bare `beanName(...)`, when the enclosing type (or the type extended) is the bean's configuration type.
3. The callee is matched by base name (argument labels are not compared: a defaulted parameter may be omitted at the call site).
4. Calls anywhere in the body count, including inside closures and nested functions. Nested type declarations are not entered.
5. A `@Bean` calling itself (recursion) is not reported.
6. Each direct bean call produces one diagnostic:
	- `id`: `bean.directCall`
	- Severity: **warning** (the build still succeeds; generation is not blocked). A direct call can be intentional (e.g. a helper that happens to be annotated), so v1 does not fail the build.
	- Location: the start of the call expression.
	- Message names the caller, the callee, and the suggested fix: take the callee's return type as a parameter.
	- One `note:` at the callee's declaration (`@Bean declared here`).
7. The diagnostic is reported even when the target has no `@ApplicationContext` (e.g. a feature module), like other per-declaration generator checks.
8. Diagnostics are sorted and rendered like every other generator diagnostic (`<file>:<line>:<column>: warning: <message>`). Generated output is **unchanged** by this feature.
9. Calls that do not resolve to a known `@Bean` are never reported: unrelated static functions, instance methods, `self.x()`, initializer calls (`Foo()`), calls to a function with the same name on an unrelated type.

### Not detected (v1 limits)

- Direct construction of a provider type (`UserService(...)` inside a `@Bean`).
- Calls through typealiases, module-qualified spellings (`MyModule.Config.bean()`), or `Config.self.bean()`.
- Indirect calls (the bean calls a helper that calls another bean), and function references that are not called (`.map(Config.makeFoo)`).
- Local shadowing: a local function or closure named like a bean is treated as the bean when called bare.
- Instance initializer bodies of types that are not `@Service` and non-`@Bean` functions.

## Acceptance criteria (BDD)

### Scenario: Qualified call to another bean warns

```
Given a @Configuration with @Bean database() and @Bean repo() whose body calls AppConfiguration.database()
When the generator runs
Then it reports a bean.directCall warning at the call
And the message suggests a parameter of the callee's return type
And generation still succeeds with the same output as without the call
```

### Scenario: Unqualified and `Self.` calls warn

```
Given a @Bean whose body calls another @Bean of the same configuration as database() or Self.database()
Then each call reports a bean.directCall warning
```

### Scenario: Call into another configuration warns

```
Given @Bean A.repo() calls B.database() where B is another @Configuration
Then a bean.directCall warning is reported at the call
```

### Scenario: Configuration extension and other files

```
Given the callee is declared in an extension, or in another file
Then the call is still detected
```

### Scenario: Nested configuration spelling

```
Given @Configuration enum Outer { enum Config { @Bean static func database() ... } }
And a bean body calls Config.database() or Outer.Config.database()
Then a bean.directCall warning is reported
```

### Scenario: Service initializer body warns

```
Given an @Service initializer whose body calls AppConfiguration.database()
Then a bean.directCall warning is reported at the call
```

### Scenario: Call inside a closure is detected

```
Given a @Bean body calls AppConfiguration.database() inside a closure
Then a bean.directCall warning is reported
```

### Scenario: Parameters and unrelated calls are not reported

```
Given a @Bean takes the other bean as a parameter
Or calls an unrelated static function, a constructor, an instance method, or its own name recursively
Then no diagnostic is reported
```

### Scenario: Diagnostics are stable and rendered as warnings

```
Given several direct calls across files
Then warnings are sorted by location with the rest of the diagnostics
And render as `<file>:<line>:<column>: warning: <message>` followed by a `note:` line
```

### Scenario: Warning does not block generation

```
Given only bean.directCall warnings
Then GenerationResult.output is non-nil and errors is empty
```

## Phase gate

Phase 1 written 2026-10-15 alongside Phases 3–4 (the task fixed the scope: warning-only diagnostic; no runtime, macro, or generated-output changes). Phase 2 has no new contracts: `GeneratorDiagnostic` already supports warnings and notes. Seam: `DeclarationScanner` records raw call sites per body; `DirectCallAnalyzer` (new, `SwiftBeansGeneratorCore`) resolves them against the scanned beans.

## Out of scope / Future work

This PR is deliberately the cheap first step. The investigation below is recorded so a later spec can pick an option.

### Investigation findings (2026-10-15)

Spring proxies `@Configuration` classes (CGLIB subclass), so `repoUsuarios()` calling `conexionBaseDatos()` goes through the container and returns the same singleton instead of a new instance.

- Today `@Bean` is `static` and dependencies come in as parameters, so the generated code **already shares singletons**. Only a `@Bean` body that calls `AppConfiguration.otherBean()` directly silently creates a second instance.
- Swift has no runtime subclass proxies. `enum` / `struct` configurations cannot be overridden at all.

### Future options (each needs its own spec)

1. **Macro-rewritten bodies**: `@Bean` (or `@Configuration`) rewrites calls to other beans inside bodies so they go through the context's registry. Hard: the macro sees one declaration only, needs a handle to the context, and cannot know the callee is a bean without cross-file information (the generator has it, the macro does not).
2. **Instance `@Bean` methods with a configuration instance owned by the context**: the context creates the configuration once and forwards `self.otherBean()` to its accessors. Needs a new calling convention for configurations (injected back-reference or a generated wrapper conforming to a generated protocol), and changes the "`@Bean` must be `static`" rule.
3. **Generated subclass of a `class` configuration**: overrides bean methods to route through the registry (closest to Spring/CGLIB). Only works for non-`final` classes; `enum` / `struct` configurations would be excluded.
4. **Promote the warning to an error** (optionally with an opt-out annotation) once false-positive data exists.
5. **Extend detection**: direct construction of provider types, module-qualified spellings, transitive calls through helpers, and `@Bean` calls in other bodies (computed properties, `static let` initializers).
6. **Fix-it**: have the plugin / macros offer a fix-it that adds the parameter.

### Explicitly out of scope for this PR

- Runtime proxies or any runtime change.
- Instance `@Bean` methods.
- Macro rewriting of bodies.
- Failing the build on a direct call.
- Changes to generated output.
