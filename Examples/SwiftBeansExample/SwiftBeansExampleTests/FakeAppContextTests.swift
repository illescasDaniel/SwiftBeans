import HTTIES
import Testing
@testable import SwiftBeansExample

@Suite("FakeAppContext")
@MainActor
struct FakeAppContextTests {
	@Test
	func `Given default FakeAppContext When resolving handler twice Then same instance`() {
		let context = FakeAppContext()
		let first = instanceID(of: context.httpDataRequestHandler)
		let second = instanceID(of: context.httpDataRequestHandler)
		#expect(first == second)
		#expect(context.httpDataRequestHandler is FakeJSONPlaceholderDataHandler)
	}

	@Test
	func `Given default FakeAppContext When resolving transient VMs Then distinct instances`() {
		let context = FakeLoggedInContext(parent: FakeAppContext())
		let item = Item(id: 1, title: "Title", detail: "Body")
		#expect(context.itemListViewModel !== context.itemListViewModel)
		#expect(context.itemDetailViewModel(item: item) !== context.itemDetailViewModel(item: item))
		#expect(context.featuresDemoViewModel !== context.featuresDemoViewModel)
	}

	@Test
	func `Given stub repository When injecting into FakeAppContext Then use case uses stub`() async throws {
		let stub = StubItemRepository(items: [
			Item(id: 99, title: "Injected", detail: "Via FakeAppContext"),
		])
		let context = FakeAppContext(itemRepository: stub)
		let items = try await context.fetchItemsUseCase.execute()
		#expect(items.map(\.id) == [99])
	}
}
