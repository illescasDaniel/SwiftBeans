import SwiftUI

/// View: depends only on `ItemListViewModel`; navigation goes through `LoggedInCoordinator`.
struct ItemListView: View {
	@Environment(LoggedInCoordinator.self) private var coordinator
	@State private var viewModel: ItemListViewModel

	init(viewModel: ItemListViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	private var isLoading: Bool {
		viewModel.state == .loading
	}

	private var statusText: String {
		switch viewModel.state {
		case .idle: "Tap refresh to load"
		case .loading: "Loading…"
		case .loaded: "\(viewModel.items.count) posts · HTTIES → Repository → UseCase → ViewModel"
		case .failed(let message): "Failed to load posts: \(message)"
		}
	}

	var body: some View {
		List {
			Section {
				Text(statusText)
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("Menu") {
				if isLoading && viewModel.items.isEmpty {
					ProgressView()
				}
				ForEach(viewModel.items) { item in
					Button {
						coordinator.push(.itemDetail(item))
					} label: {
						VStack(alignment: .leading, spacing: 4) {
							Text(item.title)
								.font(.headline)
								.foregroundStyle(.primary)
							Text(item.detail)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						.padding(.vertical, 2)
						.frame(maxWidth: .infinity, alignment: .leading)
						.contentShape(Rectangle())
					}
					.buttonStyle(.plain)
				}
			}

			Section("Explore") {
				Button("SwiftBeans features") {
					coordinator.push(.featuresDemo)
				}
			}
		}
		.navigationTitle("JSONPlaceholder")
		.toolbar {
			ToolbarItem {
				Button("Refresh") {
					Task { await viewModel.refresh() }
				}
				.disabled(isLoading)
			}
		}
		.task {
			await viewModel.refresh()
		}
	}
}

#if DEBUG
#Preview("ItemListView") {
	let context = FakeLoggedInContext(parent: FakeAppContext())
	PreviewRootView(coordinator: context.loggedInCoordinator) {
		ItemListView(viewModel: context.itemListViewModel)
	}
}
#endif
