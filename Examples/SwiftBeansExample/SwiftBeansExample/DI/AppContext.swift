import SwiftBeans

/// Root of the compile-time DI graph.
///
/// Generated accessors + `AppContextProtocol` include:
/// - `httpDataRequestHandler` / `httpClient` (from `@Configuration` + HTTIES)
/// - `itemRepository` → `JSONPlaceholderItemRepository` as `ItemRepository`
/// - `fetchItemsUseCase`
/// - transient view models, and `appCoordinator` (receives them as factories)
@ApplicationContext
final class AppContext {}
