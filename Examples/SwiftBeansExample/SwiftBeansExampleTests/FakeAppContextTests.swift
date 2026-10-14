import HTTIES
import Testing
@testable import SwiftBeansExample

@Suite("FakeAppContext")
@MainActor
struct FakeAppContextTests {
	@Test
	func `Given default FakeAppContext When resolving handler twice Then same instance`() {
		let context = FakeAppContext()
		let first = context.httpDataRequestHandler as AnyObject
		let second = context.httpDataRequestHandler as AnyObject
		#expect(first === second)
		#expect(context.httpDataRequestHandler is FakeJSONPlaceholderDataHandler)
	}

	@Test
	func `Given default FakeAppContext When resolving transient VMs Then distinct instances`() {
		let context = FakeAppContext()
		#expect(context.itemListViewModel !== context.itemListViewModel)
		#expect(context.itemDetailViewModel !== context.itemDetailViewModel)
		#expect(context.featuresDemoViewModel !== context.featuresDemoViewModel)
	}

	@Test
	func `Given stub repository When injecting into FakeAppContext Then use case uses stub`() async {
		let stub = StubItemRepository(items: [
			Item(id: 99, title: "Injected", detail: "Via FakeAppContext"),
		])
		let context = FakeAppContext(itemRepository: stub)
		let items = await context.fetchItemsUseCase.execute()
		#expect(items.map(\.id) == [99])
	}
}
