import HTTIES
import Testing
@testable import SwiftBeansExample

@Suite("AppContext scopes")
@MainActor
struct AppContextScopeTests {
	@Test
	func `Given singleton handler When resolved twice Then same instance`() {
		let context = AppContext()
		let first = context.httpDataRequestHandler as AnyObject
		let second = context.httpDataRequestHandler as AnyObject
		#expect(first === second)
	}

	@Test
	func `Given transient view models When resolved twice Then distinct instances`() {
		let context = AppContext()
		let first = context.itemListViewModel
		let second = context.itemListViewModel
		#expect(first !== second)
	}

	@Test
	func `Given protocol binding When resolving itemRepository Then returns JSONPlaceholder repository`() {
		let context = AppContext()
		#expect(context.itemRepository is JSONPlaceholderItemRepository)
	}

	@Test
	func `Given configuration beans When fetching posts Then returns fake JSONPlaceholder data`() async {
		let context = AppContext()
		let items = await context.itemRepository.fetchItems()
		#expect(items.count == 5)
		#expect(items.first?.id == 1)
	}
}
