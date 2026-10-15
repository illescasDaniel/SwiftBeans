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
	func `Given assisted detail view model When called twice Then new instances carry their items`() {
		let context = AppContext()
		let first = context.itemDetailViewModel(item: Item(id: 1, title: "One", detail: "A"))
		let second = context.itemDetailViewModel(item: Item(id: 2, title: "Two", detail: "B"))
		#expect(first !== second)
		#expect(first.item.id == 1)
		#expect(second.item.id == 2)
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
