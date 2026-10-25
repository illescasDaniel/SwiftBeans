import Observation
import SwiftBeans
import SwiftUI

/// Builds screens from injected factories, so it never sees the context:
/// `() -> T` re-reads a transient accessor, `(Item) -> T` calls an assisted accessor.
/// Transient: factories capture the context, so a singleton holding them would keep it alive.
@Service(in: LoggedInContext.self, scope: .transient)
@Observable
@MainActor
final class LoggedInCoordinator {
	var path = NavigationPath()
	var selectedTab = LoggedInTab.items
	private let makeItemList: @MainActor () -> ItemListViewModel
	private let makeItemDetail: @MainActor (Item) -> ItemDetailViewModel
	private let makeUser: @MainActor () -> UserTabViewModel
	private let makeFeaturesDemo: @MainActor () -> FeaturesDemoViewModel

	init(
		makeItemList: @escaping @MainActor () -> ItemListViewModel,
		makeItemDetail: @escaping @MainActor (Item) -> ItemDetailViewModel,
		makeUser: @escaping @MainActor () -> UserTabViewModel,
		makeFeaturesDemo: @escaping @MainActor () -> FeaturesDemoViewModel
	) {
		self.makeItemList = makeItemList
		self.makeItemDetail = makeItemDetail
		self.makeUser = makeUser
		self.makeFeaturesDemo = makeFeaturesDemo
	}

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
