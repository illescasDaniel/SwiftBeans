# Changelog

All notable changes to SwiftBeans are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/). While the version is `0.x`, minor releases may contain breaking API changes.

## [Unreleased]

### Added

- GitHub Actions CI: `swift test`, example app tests on macOS and an iOS Simulator build.
- Factory injection: a bean parameter `(Item) -> ItemDetailViewModel` is wired to the assisted accessor and `() -> T` to a deferred accessor; factories do not count as dependency cycles (`specs/factory-injection/SPEC.md`).

## [0.1.0] - 2026-10-15

First public release.

### Added

- Compile-time dependency injection: a build tool plugin (`SwiftBeansPlugin`) scans the target, validates the graph and generates plain Swift accessors on the context. Missing, duplicate or cyclic dependencies fail the build with `file:line:column` diagnostics.
- `@ApplicationContext`, `@Service` and `@Configuration` / `@Bean` macros.
- Scopes: singleton and transient beans.
- Binding beans to protocols (`any Protocol` accessors).
- `@Inject` to choose the initializer when a type has several.
- `@Assisted` runtime arguments (assisted injection), e.g. `itemDetailViewModel(item:)`.
- Generated `{Context}Protocol` (e.g. `AppContextProtocol`) for fakes in tests and SwiftUI Previews.
- `.swiftbeans.yml` to scan local packages, with automatic imports in generated code.
- Example multiplatform app (`Examples/SwiftBeansExample`) that exercises every feature and doubles as a compile check for generated code.

[Unreleased]: https://github.com/illescasDaniel/SwiftBeans/compare/0.1.0...HEAD
[0.1.0]: https://github.com/illescasDaniel/SwiftBeans/releases/tag/0.1.0
