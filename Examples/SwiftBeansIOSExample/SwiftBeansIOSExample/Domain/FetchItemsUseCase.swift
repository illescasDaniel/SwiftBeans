import Foundation
import SwiftBeans

/// Application use case. Depends on `ItemRepository` (protocol), not the fake implementation.
@Service
final class FetchItemsUseCase: Sendable {
	private let repository: ItemRepository

	init(repository: ItemRepository) {
		self.repository = repository
	}

	func execute() async -> [Item] {
		await repository.fetchItems()
	}
}
