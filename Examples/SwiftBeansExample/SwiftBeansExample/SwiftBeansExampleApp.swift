import SwiftUI

@main
struct SwiftBeansExampleApp: App {
	@State private var coordinator: AppCoordinator

	init() {
		let context = AppContext()
		_coordinator = State(initialValue: AppCoordinator(container: context))
	}

	var body: some Scene {
		WindowGroup {
			AppRootView(coordinator: coordinator)
		}
	}
}
