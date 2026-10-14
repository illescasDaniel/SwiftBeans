import Foundation
import Observation
import SwiftBeans

/// Presentation: owns UI state. Depends on `FetchItemsUseCase` only.
/// Transient so each screen can get its own instance from `AppContext`.
@Service(scope: .transient)
@Observable
@MainActor
final class ItemListViewModel {
	private let fetchItems: FetchItemsUseCase

	private(set) var items: [Item] = []
	private(set) var isLoading = false
	private(set) var statusText = "Tap refresh to load"

	init(fetchItems: FetchItemsUseCase) {
		self.fetchItems = fetchItems
	}

	func refresh() async {
		isLoading = true
		statusText = "Loading…"
		items = await fetchItems.execute()
		isLoading = false
		statusText = "\(items.count) posts · HTTIES → Repository → UseCase → ViewModel"
	}
}
