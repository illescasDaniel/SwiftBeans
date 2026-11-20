import Observation
import SwiftBeans
import SwiftUI

/// Builds screens from injected factories, so it never sees the context:
/// `() -> T` re-reads a transient accessor, `(Item) -> T` calls an assisted accessor.
/// Transient: factories capture the context, so a singleton holding them would keep it alive.
@Service(in: LoggedInContext.self, scope: .transient, autoInit: true)
@Observable
@MainActor
final class LoggedInCoordinator {
	var path = NavigationPath()
	var selectedTab = LoggedInTab.items
	private let makeItemList: @MainActor () -> ItemListViewModel
	private let makeItemDetail: @MainActor (Item) -> ItemDetailViewModel
	private let makeUser: @MainActor () -> UserTabViewModel
	private let makeFeaturesDemo: @MainActor () -> FeaturesDemoViewModel

	func push(_ route: Route) {
		path.append(route)
	}

	func resetNavigation() {
		path = NavigationPath()
	}

	@ViewBuilder
	func build(_ route: Route) -> some View {
		switch route {
		case .itemList:
			ItemListView(viewModel: makeItemList())
		case .itemDetail(let item):
			ItemDetailView(viewModel: makeItemDetail(item))
		case .user:
			UserTabView(viewModel: makeUser())
		case .featuresDemo:
			FeaturesDemoView(viewModel: makeFeaturesDemo())
		}
	}
}

enum LoggedInTab: Hashable { case items, user }
