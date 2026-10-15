import GreetingKit
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
	let greeter: any Greeter
	let stringIntDictionary: [String: Int]
	let tagSummary: TagSummary
	let featuresWelcomeBanner: Features.WelcomeBanner

	var itemListViewModel: ItemListViewModel {
		ItemListViewModel(fetchItems: fetchItemsUseCase)
	}

	func itemDetailViewModel(item: Item) -> ItemDetailViewModel {
		ItemDetailViewModel(repository: itemRepository, item: item)
	}

	var featuresDemoViewModel: FeaturesDemoViewModel {
		FeaturesDemoViewModel(httpClient: httpClient, repository: itemRepository)
	}

	init(
		httpDataRequestHandler: (any HTTPDataRequestHandler)? = nil,
		itemRepository: ItemRepository? = nil,
		greeter: (any Greeter)? = nil
	) {
		let handler = httpDataRequestHandler ?? FakeJSONPlaceholderDataHandler()
		let client = HTTPClientImpl(httpDataRequestHandler: handler)
		let repository = itemRepository
			?? JSONPlaceholderItemRepository(httpClient: client)
		self.httpDataRequestHandler = handler
		self.httpClient = client
		self.itemRepository = repository
		self.fetchItemsUseCase = FetchItemsUseCase(repository: repository)
		let greeter = greeter ?? PreviewGreeter()
		let tagCounts = AppConfiguration.tagCounts()
		let summary = TagSummary(tagCounts: tagCounts)
		self.greeter = greeter
		self.stringIntDictionary = tagCounts
		self.tagSummary = summary
		self.featuresWelcomeBanner = Features.WelcomeBanner(greeter: greeter, summary: summary)
	}
}
