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
/// Preview stand-in for `AppNavigationView`. `root` is the initial screen; pushes still go through `coordinator.path`.
struct PreviewNavigationView<Root: View>: View {
	@Environment(AppCoordinator.self) private var coordinator
	@ViewBuilder var root: () -> Root

	var body: some View {
		@Bindable var coordinator = coordinator
		NavigationStack(path: $coordinator.path) {
			root()
				.navigationDestination(for: Route.self) { route in
					coordinator.build(route)
				}
		}
	}
}

/// Preview stand-in for `AppRootView`. The `@main` app keeps using `AppRootView`.
struct PreviewRootView<Root: View>: View {
	@Bindable var coordinator: AppCoordinator
	@ViewBuilder var root: () -> Root

	var body: some View {
		PreviewNavigationView(root: root)
			.environment(coordinator)
	}
}

#Preview("Navigation") {
	let context = FakeAppContext()
	let coordinator = context.appCoordinator
	PreviewRootView(coordinator: coordinator) {
		coordinator.build(.itemList)
	}
}
#endif
