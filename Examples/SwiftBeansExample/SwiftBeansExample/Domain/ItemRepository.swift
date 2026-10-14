import Foundation

/// Port used by use cases / view models. DI binds `JSONPlaceholderItemRepository` to this.
protocol ItemRepository: Sendable {
	func fetchItems() async -> [Item]
	func fetchItem(id: Int) async -> Item?
}
