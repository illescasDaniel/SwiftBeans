import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("FetchItemsUseCase")
@MainActor
struct FetchItemsUseCaseTests {
	@Test
	func `Given FakeAppContext with stub repo When execute Then returns repository items`() async throws {
		let expected = [
			Item(id: 1, title: "Test", detail: "Detail"),
		]
		let context = FakeAppContext(itemRepository: StubItemRepository(items: expected))
		let items = try await context.fetchItemsUseCase.execute()
		#expect(items == expected)
	}

	@Test
	func `Given FakeAppContext default fakes When execute Then returns sample posts`() async throws {
		let context = FakeAppContext()
		let items = try await context.fetchItemsUseCase.execute()
		#expect(items.count == 5)
	}
}
