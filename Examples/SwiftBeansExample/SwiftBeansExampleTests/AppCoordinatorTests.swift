import Foundation
import SwiftUI
import Testing
@testable import SwiftBeansExample

@Suite("AppCoordinator")
@MainActor
struct AppCoordinatorTests {
	@Test
	func `Given coordinator When push Then path count increases`() {
		let coordinator = AppCoordinator(container: FakeAppContext())
		#expect(coordinator.path.isEmpty)

		coordinator.push(.featuresDemo)
		#expect(coordinator.path.count == 1)

		coordinator.push(.itemDetail(Item(id: 1, title: "A", detail: "B")))
		#expect(coordinator.path.count == 2)
	}

	@Test
	func `Given path When resetNavigation Then path is empty`() {
		let coordinator = AppCoordinator(container: FakeAppContext())
		coordinator.push(.featuresDemo)
		coordinator.resetNavigation()
		#expect(coordinator.path.isEmpty)
	}
}
