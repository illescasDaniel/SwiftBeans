import Observation
import SwiftUI

@Observable
final class AppCoordinator {
	var path = NavigationPath()
	private let container: any AppContextProtocol

	init(container: any AppContextProtocol) {
		self.container = container
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
			ItemListView(viewModel: container.itemListViewModel)
		case .itemDetail(let item):
			ItemDetailView(viewModel: container.itemDetailViewModel(item: item))
		case .featuresDemo:
			FeaturesDemoView(viewModel: container.featuresDemoViewModel)
		}
	}
}
