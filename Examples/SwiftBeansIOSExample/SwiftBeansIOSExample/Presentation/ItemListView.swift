import SwiftUI

/// View: depends only on `ItemListViewModel` (injected from `AppContext` in `MyApp`).
struct ItemListView: View {
	@Bindable var viewModel: ItemListViewModel

	var body: some View {
		NavigationStack {
			List {
				Section {
					Text(viewModel.statusText)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}

				Section("Menu") {
					if viewModel.isLoading && viewModel.items.isEmpty {
						ProgressView()
					}
					ForEach(viewModel.items) { item in
						VStack(alignment: .leading, spacing: 4) {
							Text(item.title)
								.font(.headline)
							Text(item.detail)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						.padding(.vertical, 2)
					}
				}
			}
			.navigationTitle("SwiftBeans MVVM")
			.toolbar {
				ToolbarItem {
					Button("Refresh") {
						Task { await viewModel.refresh() }
					}
					.disabled(viewModel.isLoading)
				}
			}
			.task {
				await viewModel.refresh()
			}
		}
	}
}

#Preview {
	// Preview bypasses the DI graph — construct the chain manually.
	ItemListView(
		viewModel: ItemListViewModel(
			fetchItems: FetchItemsUseCase(
				repository: FakeItemRepository()
			)
		)
	)
}
