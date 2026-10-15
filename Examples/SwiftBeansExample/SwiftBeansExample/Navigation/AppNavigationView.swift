import SwiftUI

struct AppNavigationView: View {
	@Environment(AppCoordinator.self) private var coordinator

	var body: some View {
		@Bindable var coordinator = coordinator
		NavigationStack(path: $coordinator.path) {
			coordinator.build(.itemList)
				.navigationDestination(for: Route.self) { route in
					coordinator.build(route)
				}
		}
	}
}

struct AppRootView: View {
	@Bindable var coordinator: AppCoordinator

	var body: some View {
		AppNavigationView()
			.environment(coordinator)
	}
}

#if DEBUG
#Preview("AppRootView") {
	let context = FakeAppContext()
	AppRootView(coordinator: context.appCoordinator)
}

#Preview("AppNavigationView") {
	let context = FakeAppContext()
	let coordinator = context.appCoordinator
	AppNavigationView()
		.environment(coordinator)
}
#endif
