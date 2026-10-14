import Foundation

/// Port used by the use case. The DI graph binds `FakeItemRepository` to this protocol.
protocol ItemRepository: Sendable {
	func fetchItems() async -> [Item]
}
