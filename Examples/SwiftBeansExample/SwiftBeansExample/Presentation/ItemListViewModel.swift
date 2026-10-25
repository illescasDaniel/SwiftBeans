import Foundation
import Observation
import SwiftBeans

/// Presentation: owns UI state. Depends on `FetchItemsUseCase` only.
/// Transient so each screen can get its own instance from `LoggedInContext`.
@Service(in: LoggedInContext.self, scope: .transient)
@Observable
@MainActor
final class ItemListViewModel {
	private let fetchItems: FetchItemsUseCase

	private(set) var items: [Item] = []
	private(set) var state: LoadState = .idle

	init(fetchItems: FetchItemsUseCase) {
		self.fetchItems = fetchItems
	}

	func refresh() async {
		state = .loading
		do {
			items = try await fetchItems.execute()
			state = .loaded
		} catch {
			state = .failed(error.localizedDescription)
		}
	}
}
