import Foundation
import SwiftUI
import Testing
@testable import SwiftBeansExample

@Suite("AppCoordinator")
@MainActor
struct AppCoordinatorTests {
	@Test
	func `Given coordinator When push Then path count increases`() {
		let coordinator = FakeAppContext().appCoordinator
		#expect(coordinator.path.isEmpty)

		coordinator.push(.featuresDemo)
		#expect(coordinator.path.count == 1)

		coordinator.push(.itemDetail(Item(id: 1, title: "A", detail: "B")))
		#expect(coordinator.path.count == 2)
	}

	@Test
	func `Given path When resetNavigation Then path is empty`() {
		let coordinator = FakeAppContext().appCoordinator
		coordinator.push(.featuresDemo)
		coordinator.resetNavigation()
		#expect(coordinator.path.isEmpty)
	}

	@Test
	func `Given injected factories When building routes Then each route uses its factory`() {
		let context = FakeAppContext()
		var listCount = 0
		var demoCount = 0
		var detailItems: [Item] = []
		let coordinator = AppCoordinator(
			makeItemList: {
				listCount += 1
				return context.itemListViewModel
			},
			makeItemDetail: {
				detailItems.append($0)
				return context.itemDetailViewModel(item: $0)
			},
			makeFeaturesDemo: {
				demoCount += 1
				return context.featuresDemoViewModel
			}
		)
		let item = Item(id: 7, title: "Seven", detail: "Body")

		_ = coordinator.build(.itemList)
		_ = coordinator.build(.itemDetail(item))
		_ = coordinator.build(.featuresDemo)
		_ = coordinator.build(.itemDetail(item))

		#expect(listCount == 1)
		#expect(demoCount == 1)
		#expect(detailItems.map(\.id) == [7, 7])
	}

	@Test
	func `Given the generated context When resolving the coordinator twice Then each is a new instance`() {
		let context = AppContext()
		#expect(context.appCoordinator !== context.appCoordinator)
	}
}
