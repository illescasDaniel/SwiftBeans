import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("ItemDetailViewModel")
@MainActor
struct ItemDetailViewModelTests {
	@Test
	func `Given FakeAppContext with stub repo When refresh Then refreshes from repository`() async {
		let seed = Item(id: 7, title: "Seed", detail: "Old")
		let refreshed = Item(id: 7, title: "Fresh", detail: "New body")
		let context = FakeAppContext(itemRepository: StubItemRepository(items: [refreshed]))
		let viewModel = context.itemDetailViewModel(item: seed)
		#expect(viewModel.item == seed)
		#expect(viewModel.state == .idle)

		await viewModel.refresh()

		#expect(viewModel.item == refreshed)
		#expect(viewModel.state == .loaded)
	}

	@Test
	func `Given FakeAppContext default fakes When refresh post 1 Then uses fake JSONPlaceholder data`() async {
		let context = FakeAppContext()
		let viewModel = context.itemDetailViewModel(item: Item(id: 1, title: "Seed", detail: "Old"))

		await viewModel.refresh()

		#expect(viewModel.item.id == 1)
		#expect(viewModel.item.title.contains("sunt aut"))
		#expect(viewModel.state == .loaded)
	}

	@Test
	func `Given failing repository When refresh Then state is failed and seed item is kept`() async {
		let seed = Item(id: 7, title: "Seed", detail: "Old")
		let context = FakeAppContext(itemRepository: StubItemRepository(items: [], shouldThrow: true))
		let viewModel = context.itemDetailViewModel(item: seed)

		await viewModel.refresh()

		guard case .failed = viewModel.state else {
			Issue.record("Expected .failed, got \(viewModel.state)")
			return
		}
		#expect(viewModel.item == seed)
	}
}
