import Foundation
import GreetingKit
import HTTIES

#if DEBUG
/// Hand-written stand-in for generated `AppContext`, conforming to `AppContextProtocol`.
///
/// Use in SwiftUI Previews and tests that need the full graph without production wiring.
@MainActor
final class FakeAppContext: AppContextProtocol {
	let httpDataRequestHandler: any HTTPDataRequestHandler
	let httpClient: any HTTPClient
	let jsonDecoder: JSONDecoder
	let snakeCaseJSONDecoder: JSONDecoder
	let snakeCaseReader: SnakeCaseReader
	let itemRepository: ItemRepository
	let fetchItemsUseCase: FetchItemsUseCase
	let greeter: any Greeter
	let shortGreeter: any Greeter
	let greetingStyles: GreetingStyles
	let stringIntDictionary: [String: Int]
	let tagSummary: TagSummary
	let featuresWelcomeBanner: Features.WelcomeBanner
	let builtinStaticTagSource: StaticTagSource
	let remoteTagSource: any TagSource
	let tagSourcePair: TagSourcePair
	let assistedFeatureNote: AssistedFeatureNote
	let collectionFeatureNote: CollectionFeatureNote
	let factoryFeatureNote: FactoryFeatureNote
	let qualifierFeatureNote: QualifierFeatureNote
	let highlightsFeatureNoteArray: [any FeatureNote]

	let authenticationService: AuthenticationService
	var loginViewModel: LoginViewModel { LoginViewModel(authentication: authenticationService) }

	var featuresDemoViewModel: FeaturesDemoViewModel {
		FeaturesDemoViewModel(
			repository: itemRepository,
			welcomeBanner: featuresWelcomeBanner,
			httpDataRequestHandler: httpDataRequestHandler,
			snakeCaseReader: snakeCaseReader,
			greetingStyles: greetingStyles,
			tagSources: tagSourcePair,
			notes: [assistedFeatureNote, collectionFeatureNote, factoryFeatureNote, qualifierFeatureNote],
			highlightedNotes: highlightsFeatureNoteArray
		)
	}

	init(
		httpDataRequestHandler: (any HTTPDataRequestHandler)? = nil,
		itemRepository: ItemRepository? = nil,
		greeter: (any Greeter)? = nil
	) {
		self.authenticationService = AuthenticationService()
		let handler = httpDataRequestHandler ?? FakeJSONPlaceholderDataHandler()
		let client = HTTPClientImpl(httpDataRequestHandler: handler)
		let decoder = AppConfiguration.decoder()
		let snakeCaseDecoder = AppConfiguration.snakeCaseDecoder()
		let repository = itemRepository
			?? JSONPlaceholderItemRepository(httpClient: client, decoder: decoder)
		self.httpDataRequestHandler = handler
		self.httpClient = client
		self.jsonDecoder = decoder
		self.snakeCaseJSONDecoder = snakeCaseDecoder
		self.snakeCaseReader = SnakeCaseReader(decoder: snakeCaseDecoder)
		self.itemRepository = repository
		self.fetchItemsUseCase = FetchItemsUseCase(repository: repository)
		let greeter = greeter ?? PreviewGreeter()
		let short = AppConfiguration.shortGreeter()
		let tagCounts = AppConfiguration.tagCounts()
		let summary = TagSummary(tagCounts: tagCounts)
		self.greeter = greeter
		self.shortGreeter = short
		self.greetingStyles = GreetingStyles(greeter: greeter, shortGreeter: short)
		self.stringIntDictionary = tagCounts
		self.tagSummary = summary
		self.featuresWelcomeBanner = Features.WelcomeBanner(greeter: greeter, summary: summary)
		let builtin = StaticTagSource()
		let remote = RemoteTagSource()
		self.builtinStaticTagSource = builtin
		self.remoteTagSource = remote
		self.tagSourcePair = TagSourcePair(builtin: builtin, remote: remote)
		let assisted = AssistedFeatureNote()
		let factory = FactoryFeatureNote()
		self.assistedFeatureNote = assisted
		self.collectionFeatureNote = CollectionFeatureNote()
		self.factoryFeatureNote = factory
		self.qualifierFeatureNote = QualifierFeatureNote()
		self.highlightsFeatureNoteArray = [factory, assisted]
	}
}
#endif
