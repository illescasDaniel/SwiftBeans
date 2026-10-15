import Foundation
@testable import SwiftBeansExample

/// Controllable `ItemRepository` for unit tests injected through `FakeAppContext`.
struct StubItemRepository: ItemRepository {
	struct StubError: Error {}

	let items: [Item]
	var shouldThrow = false

	func fetchItems() async throws -> [Item] {
		if shouldThrow { throw StubError() }
		return items
	}

	func fetchItem(id: Int) async throws -> Item {
		if shouldThrow { throw StubError() }
		guard let item = items.first(where: { $0.id == id }) else { throw StubError() }
		return item
	}
}
