import Foundation
import Testing
@testable import SwiftBeansExample

@Suite("ItemDetailViewModel")
@MainActor
struct ItemDetailViewModelTests {
	@Test
	func `Given FakeAppContext with stub repo When load Then refreshes from repository`() async {
		let seed = Item(id: 7, title: "Seed", detail: "Old")
		let refreshed = Item(id: 7, title: "Fresh", detail: "New body")
		let context = FakeAppContext(itemRepository: StubItemRepository(items: [refreshed]))
		let viewModel = context.itemDetailViewModel

		await viewModel.load(seed: seed)

		#expect(viewModel.item == refreshed)
		#expect(viewModel.isLoading == false)
		#expect(viewModel.statusText.contains("HTTIES"))
	}

	@Test
	func `Given FakeAppContext default fakes When load post 1 Then uses fake JSONPlaceholder data`() async {
		let context = FakeAppContext()
		let viewModel = context.itemDetailViewModel
		let seed = Item(id: 1, title: "Seed", detail: "Old")

		await viewModel.load(seed: seed)

		#expect(viewModel.item?.id == 1)
		#expect(viewModel.item?.title.contains("sunt aut") == true)
	}
}
