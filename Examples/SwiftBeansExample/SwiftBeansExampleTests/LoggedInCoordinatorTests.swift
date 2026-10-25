import Foundation
import SwiftUI
import Testing

@testable import SwiftBeansExample

@Suite("LoggedInCoordinator")
@MainActor
struct LoggedInCoordinatorTests {
	@Test
	func `Given coordinator When push Then path count increases`() {
		let coordinator = FakeLoggedInContext(parent: FakeAppContext()).loggedInCoordinator
		#expect(coordinator.path.isEmpty)

		coordinator.push(.featuresDemo)
		#expect(coordinator.path.count == 1)

		coordinator.push(.itemDetail(Item(id: 1, title: "A", detail: "B")))
		#expect(coordinator.path.count == 2)
	}

	@Test
	func `Given path When resetNavigation Then path is empty`() {
		let coordinator = FakeLoggedInContext(parent: FakeAppContext()).loggedInCoordinator
		coordinator.push(.featuresDemo)
		coordinator.resetNavigation()
		#expect(coordinator.path.isEmpty)
	}

	@Test
	func `Given injected factories When building routes Then each route uses its factory`() {
		let context = FakeLoggedInContext(parent: FakeAppContext())
		var listCount = 0
		var demoCount = 0
		var userCount = 0
		var detailItems: [Item] = []
		let coordinator = LoggedInCoordinator(
			makeItemList: {
				listCount += 1
				return context.itemListViewModel
			},
			makeItemDetail: {
				detailItems.append($0)
				return context.itemDetailViewModel(item: $0)
			},
			makeUser: {
				userCount += 1
				return context.userTabViewModel
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
		_ = coordinator.build(.user)
		_ = coordinator.build(.itemDetail(item))

		#expect(listCount == 1)
		#expect(demoCount == 1)
		#expect(userCount == 1)
		#expect(detailItems.map(\.id) == [7, 7])
	}

	@Test
	func `Given the generated context When resolving the coordinator twice Then each is a new instance`() {
		let context = LoggedInContext(parent: AppContext(), credentials: .preview)
		#expect(context.loggedInCoordinator !== context.loggedInCoordinator)
	}
	@Test func `Given a logged in flow When tabs and routes change Then session stays open`() async {
		let context = FakeLoggedInContext(parent: FakeAppContext())
		let coordinator = context.loggedInCoordinator
		let repository = context.userRepository
		coordinator.selectedTab = .user
		_ = coordinator.build(.user)
		coordinator.selectedTab = .items
		coordinator.push(.featuresDemo)
		coordinator.resetNavigation()
		#expect(context.closeCount == 0)
		#expect(context.userRepository === repository)
		#expect(!repository.isClosed)
		await context.close()
	}

}
