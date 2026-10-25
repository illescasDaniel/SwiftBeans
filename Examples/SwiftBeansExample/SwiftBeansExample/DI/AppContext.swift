import SwiftBeans

/// Root of the compile-time DI graph.
///
/// Generated accessors + `AppContextProtocol` include:
/// - `httpDataRequestHandler` / `httpClient` (from `@Configuration` + HTTIES)
/// - `jsonDecoder` and `snakeCaseJSONDecoder` (`@Bean(named:)` / `@Qualifier`)
/// - `itemRepository` → `JSONPlaceholderItemRepository` as `ItemRepository`
/// - `fetchItemsUseCase`
/// - `[any FeatureNote]` collection injection and the explicit `highlightsFeatureNoteArray` bean
/// - named `TagSource`s
/// - authentication and transient login/features models
/// `LoggedInContext` owns session repositories, screen models and its transient coordinator.
///
/// A successful build also writes `SwiftBeansGraph.md` and `SwiftBeansGraph.dot`
/// next to `SwiftBeansGenerated.swift` in the plugin output directory.
@ApplicationContext
@MainActor
final class AppContext {}
