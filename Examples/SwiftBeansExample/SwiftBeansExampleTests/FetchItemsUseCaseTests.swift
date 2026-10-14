import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("FetchItemsUseCase")
@MainActor
struct FetchItemsUseCaseTests {
	@Test
	func `Given FakeAppContext with stub repo When execute Then returns repository items`() async {
		let expected = [
			Item(id: 1, title: "Test", detail: "Detail"),
		]
		let context = FakeAppContext(itemRepository: StubItemRepository(items: expected))
		let items = await context.fetchItemsUseCase.execute()
		#expect(items == expected)
	}

	@Test
	func `Given FakeAppContext default fakes When execute Then returns sample posts`() async {
		let context = FakeAppContext()
		let items = await context.fetchItemsUseCase.execute()
		#expect(items.count == 5)
	}
}
