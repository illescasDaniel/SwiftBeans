import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("JSONPlaceholderItemRepository")
@MainActor
struct JSONPlaceholderItemRepositoryTests {
	@Test
	func `Given FakeAppContext When fetchItems Then maps posts to items`() async throws {
		let context = FakeAppContext()
		let items = try await context.itemRepository.fetchItems()

		#expect(items.count == 5)
		#expect(items[0].title.contains("sunt aut"))
	}

	@Test
	func `Given FakeAppContext When fetchItem Then returns matching post`() async throws {
		let context = FakeAppContext()
		let item = try await context.itemRepository.fetchItem(id: 2)

		#expect(item.id == 2)
		#expect(item.title == "qui est esse")
	}

	@Test
	func `Given FakeAppContext When fetchItem for unknown id Then throws`() async {
		let context = FakeAppContext()
		await #expect(throws: (any Error).self) {
			try await context.itemRepository.fetchItem(id: 999)
		}
	}
}
