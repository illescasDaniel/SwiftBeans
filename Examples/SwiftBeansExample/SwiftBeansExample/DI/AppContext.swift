import SwiftBeans

/// Root of the compile-time DI graph.
///
/// Generated accessors + `AppContextProtocol` include:
/// - `httpDataRequestHandler` / `httpClient` (from `@Configuration` + HTTIES)
/// - `jsonDecoder` and `snakeCaseJSONDecoder` (`@Bean(named:)` / `@Qualifier`)
/// - `itemRepository` → `JSONPlaceholderItemRepository` as `ItemRepository`
/// - `fetchItemsUseCase`
/// - `[any FeatureNote]` on the features demo, and named `TagSource`s
/// - transient view models, and `appCoordinator` (receives them as factories)
///
/// A successful build also writes `SwiftBeansGraph.md` and `SwiftBeansGraph.dot`
/// next to `SwiftBeansGenerated.swift` in the plugin output directory.
@ApplicationContext
final class AppContext {}
