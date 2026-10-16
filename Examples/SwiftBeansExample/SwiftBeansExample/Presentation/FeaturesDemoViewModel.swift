import Foundation
import HTTIES
import Observation
import SwiftBeans

/// Transient VM for the feature-graph screen. Gets everything the screen shows from the graph.
@Service(scope: .transient)
@Observable
@MainActor
final class FeaturesDemoViewModel {
	private let repository: ItemRepository

	let welcomeBannerMessage: String
	/// Concrete type of the active `httpDataRequestHandler` bean.
	let handlerDescription: String
	/// Decoded with `@Qualifier("snakeCase")`, not the repository's decoder.
	let snakeCaseTitle: String
	let standardGreeting: String
	let shortGreeting: String
	let builtinTagLabel: String
	let remoteTagLabel: String
	/// Every `FeatureNote`, injected as `[any FeatureNote]`.
	let featureNotes: [any FeatureNote]

	private(set) var sampleTitle: String?
	private(set) var state: LoadState = .idle

	init(
		repository: ItemRepository,
		welcomeBanner: Features.WelcomeBanner,
		httpDataRequestHandler: any HTTPDataRequestHandler,
		snakeCaseReader: SnakeCaseReader,
		greetingStyles: GreetingStyles,
		tagSources: TagSourcePair,
		notes: [any FeatureNote]
	) {
		self.repository = repository
		self.welcomeBannerMessage = welcomeBanner.message
		self.handlerDescription = String(describing: type(of: httpDataRequestHandler))
		self.snakeCaseTitle = (try? snakeCaseReader.title(from: SnakeCaseReader.sampleJSON)) ?? "decode failed"
		self.standardGreeting = greetingStyles.standard
		self.shortGreeting = greetingStyles.short
		self.builtinTagLabel = tagSources.builtinLabel
		self.remoteTagLabel = tagSources.remoteLabel
		self.featureNotes = notes
	}

	func fetchSamplePost() async {
		state = .loading
		do {
			let item = try await repository.fetchItem(id: 1)
			sampleTitle = item.title
			state = .loaded
		} catch {
			sampleTitle = nil
			state = .failed(error.localizedDescription)
		}
	}
}
