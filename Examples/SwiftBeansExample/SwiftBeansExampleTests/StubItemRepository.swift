import Foundation
@testable import SwiftBeansExample

/// Controllable `ItemRepository` for unit tests injected through `FakeAppContext`.
struct StubItemRepository: ItemRepository {
	let items: [Item]

	func fetchItems() async -> [Item] { items }

	func fetchItem(id: Int) async -> Item? {
		items.first { $0.id == id }
	}
}
