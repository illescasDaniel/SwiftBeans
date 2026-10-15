import Observation
import SwiftBeans
import SwiftUI

/// Builds screens from injected factories, so it never sees the context:
/// `() -> T` re-reads a transient accessor, `(Item) -> T` calls an assisted accessor.
/// Transient: factories capture the context, so a singleton holding them would keep it alive.
@Service(scope: .transient)
@Observable
final class AppCoordinator {
	var path = NavigationPath()
	private let makeItemList: () -> ItemListViewModel
	private let makeItemDetail: (Item) -> ItemDetailViewModel
	private let makeFeaturesDemo: () -> FeaturesDemoViewModel

	init(
		makeItemList: @escaping () -> ItemListViewModel,
		makeItemDetail: @escaping (Item) -> ItemDetailViewModel,
		makeFeaturesDemo: @escaping () -> FeaturesDemoViewModel
	) {
		self.makeItemList = makeItemList
		self.makeItemDetail = makeItemDetail
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
		case .featuresDemo:
			FeaturesDemoView(viewModel: makeFeaturesDemo())
		}
	}
}
