import Foundation
import SwiftBeans

/// Fake data source. Bound to `ItemRepository` so use cases depend on the protocol.
@Service(boundTo: ItemRepository.self)
final class FakeItemRepository: ItemRepository, Sendable {
	func fetchItems() async -> [Item] {
		try? await Task.sleep(for: .milliseconds(400))
		return [
			Item(id: UUID(), title: "Espresso", detail: "Short and strong"),
			Item(id: UUID(), title: "Flat White", detail: "Silky microfoam"),
			Item(id: UUID(), title: "Cold Brew", detail: "Steeped overnight"),
		]
	}
}
