import Foundation

/// Port used by use cases / view models. DI binds `JSONPlaceholderItemRepository` to this.
protocol ItemRepository: Sendable {
	func fetchItems() async throws -> [Item]
	/// Throws when the item can't be loaded (including not found).
	func fetchItem(id: Int) async throws -> Item
}
