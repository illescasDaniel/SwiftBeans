import Foundation
import Observation
import SwiftBeans

/// Presentation: owns UI state. Depends on `FetchItemsUseCase` only.
/// Transient so each screen can get its own instance from `LoggedInContext`.
@Service(in: LoggedInContext.self, scope: .transient, autoInit: true)
@Observable
@MainActor
final class ItemListViewModel {
	private let fetchItems: FetchItemsUseCase

	private(set) var items: [Item] = []
	private(set) var state: LoadState = .idle

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
