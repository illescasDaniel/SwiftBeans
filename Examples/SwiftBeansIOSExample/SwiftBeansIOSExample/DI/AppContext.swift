import SwiftBeans

/// Root of the compile-time DI graph.
///
/// After a successful build, `SwiftBeansPlugin` generates accessors such as:
/// - `itemRepository` → `FakeItemRepository` as `ItemRepository`
/// - `fetchItemsUseCase`
/// - `itemListViewModel` (transient)
///
/// Declared services live next to their layers:
/// - `FakeItemRepository` (`Data/`)
/// - `FetchItemsUseCase` (`Domain/`)
/// - `ItemListViewModel` (`Presentation/`)
@ApplicationContext
final class AppContext {}
