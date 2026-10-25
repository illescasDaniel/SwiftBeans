import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("ItemListViewModel")
@MainActor
struct ItemListViewModelTests {
	@Test
	func `Given FakeAppContext with stub repo When refresh Then loads items and reaches loaded`() async {
		let items = [
			Item(id: 1, title: "Post", detail: "Body"),
		]
		let context = FakeLoggedInContext(parent: FakeAppContext(itemRepository: StubItemRepository(items: items)))
		let viewModel = context.itemListViewModel
		#expect(viewModel.state == .idle)

		await viewModel.refresh()

		#expect(viewModel.items == items)
		#expect(viewModel.state == .loaded)
	}

	@Test
	func `Given FakeAppContext default fakes When refresh Then loads JSONPlaceholder sample posts`() async {
		let context = FakeLoggedInContext(parent: FakeAppContext())
		let viewModel = context.itemListViewModel

		await viewModel.refresh()

		#expect(viewModel.items.count == 5)
		#expect(viewModel.state == .loaded)
	}

	@Test
	func `Given failing repository When refresh Then state is failed and items stay empty`() async {
		let context = FakeLoggedInContext(parent: FakeAppContext(itemRepository: StubItemRepository(items: [], shouldThrow: true)))
		let viewModel = context.itemListViewModel

		await viewModel.refresh()

		guard case .failed = viewModel.state else {
			Issue.record("Expected .failed, got \(viewModel.state)")
			return
		}
		#expect(viewModel.items.isEmpty)
	}
}
