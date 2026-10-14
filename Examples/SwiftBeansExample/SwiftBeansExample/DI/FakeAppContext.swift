import HTTIES

/// Hand-written stand-in for generated `AppContext`, conforming to `AppContextProtocol`.
///
/// Use in SwiftUI Previews and tests that need the full graph without production wiring.
@MainActor
final class FakeAppContext: AppContextProtocol {
	let httpDataRequestHandler: any HTTPDataRequestHandler
	let httpClient: any HTTPClient
	let itemRepository: ItemRepository
	let fetchItemsUseCase: FetchItemsUseCase

	var itemListViewModel: ItemListViewModel {
		ItemListViewModel(fetchItems: fetchItemsUseCase)
	}

	var itemDetailViewModel: ItemDetailViewModel {
		ItemDetailViewModel(repository: itemRepository)
	}

	var featuresDemoViewModel: FeaturesDemoViewModel {
		FeaturesDemoViewModel(httpClient: httpClient, repository: itemRepository)
	}

	init(
		httpDataRequestHandler: (any HTTPDataRequestHandler)? = nil,
		itemRepository: ItemRepository? = nil
	) {
		let handler = httpDataRequestHandler ?? FakeJSONPlaceholderDataHandler()
		let client = HTTPClientImpl(httpDataRequestHandler: handler)
		let repository = itemRepository
			?? JSONPlaceholderItemRepository(httpClient: client)
		self.httpDataRequestHandler = handler
		self.httpClient = client
		self.itemRepository = repository
		self.fetchItemsUseCase = FetchItemsUseCase(repository: repository)
	}
}
