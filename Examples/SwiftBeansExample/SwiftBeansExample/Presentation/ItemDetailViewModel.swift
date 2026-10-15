import Foundation
import Observation
import SwiftBeans

/// Detail screen VM; the item is a runtime argument, so the context exposes `itemDetailViewModel(item:)`.
@Service
@Observable
@MainActor
final class ItemDetailViewModel {
	private let repository: ItemRepository

	private(set) var item: Item
	private(set) var isLoading = false
	private(set) var statusText = ""

	init(repository: ItemRepository, @Assisted item: Item) {
		self.repository = repository
		self.item = item
	}

	func refresh() async {
		isLoading = true
		statusText = "Refreshing from API…"
		if let refreshed = await repository.fetchItem(id: item.id) {
			item = refreshed
			statusText = "Loaded post #\(refreshed.id) via HTTIES"
		} else {
			statusText = "Showing seed data (fetch failed or offline fake miss)"
		}
		isLoading = false
	}
}
