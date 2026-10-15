import SwiftUI

struct ItemDetailView: View {
	@Bindable var viewModel: ItemDetailViewModel

	var body: some View {
		List {
			Section("Post") {
				Text(viewModel.item.title)
					.font(.headline)
				Text(viewModel.item.detail)
					.foregroundStyle(.secondary)
			}

			Section {
				Text(viewModel.statusText)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.navigationTitle("#\(viewModel.item.id)")
		.task {
			await viewModel.refresh()
		}
	}
}

#Preview("ItemDetailView") {
	let context = FakeAppContext()
	NavigationStack {
		ItemDetailView(
			viewModel: context.itemDetailViewModel(item: Item(id: 1, title: "Preview", detail: "Body"))
		)
	}
}
