import SwiftUI

struct ItemDetailView: View {
	@State private var viewModel: ItemDetailViewModel

	init(viewModel: ItemDetailViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	private var statusText: String {
		switch viewModel.state {
		case .idle: ""
		case .loading: "Refreshing from API…"
		case .loaded: "Loaded post #\(viewModel.item.id) via HTTIES"
		case .failed(let message): "Showing seed data (refresh failed: \(message))"
		}
	}

	var body: some View {
		List {
			Section("Post") {
				Text(viewModel.item.title)
					.font(.headline)
				Text(viewModel.item.detail)
					.foregroundStyle(.secondary)
			}

			Section {
				Text(statusText)
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

#if DEBUG
#Preview("ItemDetailView") {
	let context = FakeLoggedInContext(parent: FakeAppContext())
	PreviewRootView(coordinator: context.loggedInCoordinator) {
		ItemDetailView(
			viewModel: context.itemDetailViewModel(item: Item(id: 1, title: "Preview", detail: "Body"))
		)
	}
}
#endif
