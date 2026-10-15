import Foundation
import HTTIES
import Observation
import SwiftBeans

/// Transient VM for the HTTIES + `@Bean` demo screen. Gets everything the screen shows from the graph.
@Service(scope: .transient)
@Observable
@MainActor
final class FeaturesDemoViewModel {
	private let repository: ItemRepository

	let welcomeBannerMessage: String
	/// Concrete type of the active `httpDataRequestHandler` bean.
	let handlerDescription: String

	private(set) var sampleTitle: String?
	private(set) var state: LoadState = .idle

	init(
		repository: ItemRepository,
		welcomeBanner: Features.WelcomeBanner,
		httpDataRequestHandler: any HTTPDataRequestHandler
	) {
		self.repository = repository
		self.welcomeBannerMessage = welcomeBanner.message
		self.handlerDescription = String(describing: type(of: httpDataRequestHandler))
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
