import SwiftUI

struct ItemDetailView: View {
	@Bindable var viewModel: ItemDetailViewModel
	let seed: Item

	var body: some View {
		List {
			Section("Post") {
				if let item = viewModel.item {
					Text(item.title)
						.font(.headline)
					Text(item.detail)
						.foregroundStyle(.secondary)
				} else {
					ProgressView()
				}
			}

			Section {
				Text(viewModel.statusText)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}
		}
		.navigationTitle(viewModel.item.map { "#\($0.id)" } ?? "Post")
		.task {
			await viewModel.load(seed: seed)
		}
	}
}

#Preview("ItemDetailView") {
	let context = FakeAppContext()
	NavigationStack {
		ItemDetailView(
			viewModel: context.itemDetailViewModel,
			seed: Item(id: 1, title: "Preview", detail: "Body")
		)
	}
}
