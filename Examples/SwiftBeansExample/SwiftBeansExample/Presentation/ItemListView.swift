import SwiftUI

/// View: depends only on `ItemListViewModel`; navigation goes through `AppCoordinator`.
struct ItemListView: View {
	@Environment(AppCoordinator.self) private var coordinator
	@Bindable var viewModel: ItemListViewModel

	var body: some View {
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
				Button("HTTIES + @Bean demo") {
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
				.disabled(viewModel.isLoading)
			}
		}
		.task {
			await viewModel.refresh()
		}
	}
}

#Preview("ItemListView") {
	let context = FakeAppContext()
	let coordinator = AppCoordinator(container: context)
	NavigationStack {
		ItemListView(viewModel: context.itemListViewModel)
	}
	.environment(coordinator)
}
