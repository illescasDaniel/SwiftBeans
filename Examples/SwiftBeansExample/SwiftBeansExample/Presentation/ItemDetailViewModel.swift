import Foundation
import Observation
import SwiftBeans

/// Transient detail screen VM.
@Service(scope: .transient)
@Observable
@MainActor
final class ItemDetailViewModel {
	private let repository: ItemRepository

	private(set) var item: Item?
	private(set) var isLoading = false
	private(set) var statusText = ""

	init(repository: ItemRepository) {
		self.repository = repository
	}

	func load(seed: Item) async {
		item = seed
		isLoading = true
		statusText = "Refreshing from API…"
		if let refreshed = await repository.fetchItem(id: seed.id) {
			item = refreshed
			statusText = "Loaded post #\(refreshed.id) via HTTIES"
		} else {
			statusText = "Showing seed data (fetch failed or offline fake miss)"
		}
		isLoading = false
	}
}
