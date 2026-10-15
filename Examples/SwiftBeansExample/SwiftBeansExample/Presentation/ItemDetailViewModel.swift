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
	private(set) var state: LoadState = .idle

	init(repository: ItemRepository, @Assisted item: Item) {
		self.repository = repository
		self.item = item
	}

	func refresh() async {
		state = .loading
		do {
			item = try await repository.fetchItem(id: item.id)
			state = .loaded
		} catch {
			// Keep the seed item on screen.
			state = .failed(error.localizedDescription)
		}
	}
}
