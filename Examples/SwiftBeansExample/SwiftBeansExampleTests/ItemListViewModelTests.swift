import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("ItemListViewModel")
@MainActor
struct ItemListViewModelTests {
	@Test
	func `Given FakeAppContext with stub repo When refresh Then loads items and clears loading`() async {
		let items = [
			Item(id: 1, title: "Post", detail: "Body"),
		]
		let context = FakeAppContext(itemRepository: StubItemRepository(items: items))
		let viewModel = context.itemListViewModel

		await viewModel.refresh()

		#expect(viewModel.items == items)
		#expect(viewModel.isLoading == false)
		#expect(viewModel.statusText.contains("1 posts"))
	}

	@Test
	func `Given FakeAppContext default fakes When refresh Then loads JSONPlaceholder sample posts`() async {
		let context = FakeAppContext()
		let viewModel = context.itemListViewModel

		await viewModel.refresh()

		#expect(viewModel.items.count == 5)
		#expect(viewModel.isLoading == false)
	}
}
