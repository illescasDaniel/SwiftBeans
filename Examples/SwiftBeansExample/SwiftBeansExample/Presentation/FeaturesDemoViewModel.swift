import Foundation
import HTTIES
import Observation
import SwiftBeans

/// Transient VM that exercises the HTTIES client from the DI graph.
@Service(scope: .transient)
@Observable
@MainActor
final class FeaturesDemoViewModel {
	private let httpClient: any HTTPClient
	private let repository: ItemRepository

	private(set) var sampleTitle: String?
	private(set) var statusText = "Tap fetch to load post #1"
	private(set) var isLoading = false

	init(httpClient: any HTTPClient, repository: ItemRepository) {
		self.httpClient = httpClient
		self.repository = repository
	}

	func fetchSamplePost() async {
		isLoading = true
		statusText = "GET /posts/1 via HTTIES…"
		if let item = await repository.fetchItem(id: 1) {
			sampleTitle = item.title
			statusText = "OK — post #\(item.id)"
		} else {
			sampleTitle = nil
			statusText = "Request failed"
		}
		isLoading = false
	}
}
