import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("JSONPlaceholderItemRepository")
struct JSONPlaceholderItemRepositoryTests {
	@Test
	func `Given FakeAppContext When fetchItems Then maps posts to items`() async {
		let context = FakeAppContext()
		let items = await context.itemRepository.fetchItems()

		#expect(items.count == 5)
		#expect(items[0].title.contains("sunt aut"))
	}

	@Test
	func `Given FakeAppContext When fetchItem Then returns matching post`() async {
		let context = FakeAppContext()
		let item = await context.itemRepository.fetchItem(id: 2)

		#expect(item?.id == 2)
		#expect(item?.title == "qui est esse")
	}
}
