import SwiftUI

struct LoggedInNavigationView: View {
	@Environment(LoggedInCoordinator.self) private var coordinator
	let onLogOut: @MainActor () async -> Void
	let onSessionExpired: @MainActor () async -> Void

	var body: some View {
		@Bindable var coordinator = coordinator
		TabView(selection: $coordinator.selectedTab) {
			NavigationStack(path: $coordinator.path) {
				coordinator.build(.itemList)
					.navigationDestination(for: Route.self) { coordinator.build($0) }
			}
			.tabItem { Label("Items", systemImage: "list.bullet") }
			.tag(LoggedInTab.items)
			NavigationStack {
				coordinator.build(.user)
					.toolbar {
						Button("Log Out") { Task { await onLogOut() } }
						Button("Expire Session") { Task { await onSessionExpired() } }
					}
			}
			.tabItem { Label("User", systemImage: "person") }
			.tag(LoggedInTab.user)
		}
	}
}

struct AppRootView: View {
	let coordinator: AppCoordinator
	let session: AppSession
	var body: some View {
		Group {
			if let flow = session.loggedIn {
				LoggedInNavigationView(
					onLogOut: { await session.logOut() },
					onSessionExpired: { await session.sessionExpired() }
				)
				.environment(flow.coordinator)
				.id(flow.id)
			} else {
				NavigationStack { coordinator.build(.login) }.disabled(session.isEndingSession)
			}
		}
	}
}

#if DEBUG
	struct PreviewNavigationView<Root: View>: View {
		@Environment(LoggedInCoordinator.self) private var coordinator
		@ViewBuilder var root: () -> Root
		var body: some View {
			@Bindable var coordinator = coordinator
			NavigationStack(path: $coordinator.path) {
				root().navigationDestination(for: Route.self) { coordinator.build($0) }
			}
		}
	}

	struct PreviewRootView<Root: View>: View {
		@Bindable var coordinator: LoggedInCoordinator
		@ViewBuilder var root: () -> Root
		var body: some View { PreviewNavigationView(root: root).environment(coordinator) }
	}

	#Preview("Navigation") {
		let context = FakeLoggedInContext(parent: FakeAppContext())
		PreviewRootView(coordinator: context.loggedInCoordinator) {
			context.loggedInCoordinator.build(.itemList)
		}
	}
#endif
