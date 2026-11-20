import Foundation
import SwiftBeans

/// Application use case. Depends on `ItemRepository` (protocol), not the fake implementation.
@Service(autoInit: true)
final class FetchItemsUseCase: Sendable {
	private let repository: ItemRepository

	func execute() async throws -> [Item] {
		try await repository.fetchItems()
	}
}
