import SwiftBeans

#if DEBUG
	/// Hand-written child fake using the real managed-registry lifetime contract.
	@MainActor
	final class FakeLoggedInContext: LoggedInContextProtocol {
		let credentials: SessionCredentials
		private let parent: any AppContextProtocol
		private let registry = SwiftBeansManagedRegistry(contextName: "FakeLoggedInContext")
		private let hook: CleanupHook

		private final class CleanupHook: ContextCleanup {
			var count = 0
			var action: (@MainActor () async -> Void)?
			func close() async {
				count += 1
				await action?()
			}
		}
		var closeCount: Int { hook.count }
		var onClose: (@MainActor () async -> Void)? {
			get { hook.action }
			set { hook.action = newValue }
		}

		init(parent: any AppContextProtocol, credentials: SessionCredentials = .preview) {
			self.parent = parent
			self.credentials = credentials
			let hook = CleanupHook()
			self.hook = hook
			_ = registry.singleton(key: "cleanupHook") { hook }
		}

		var userRepository: UserRepository {
			registry.singleton(key: "userRepository") {
				UserRepository(credentials: credentials, catalog: parent.itemRepository)
			}
		}
		var userTabViewModel: UserTabViewModel {
			registry.requireOpen()
			return UserTabViewModel(repository: userRepository)
		}
		var itemListViewModel: ItemListViewModel {
			registry.requireOpen()
			return ItemListViewModel(fetchItems: parent.fetchItemsUseCase)
		}
		func itemDetailViewModel(item: Item) -> ItemDetailViewModel {
			registry.requireOpen()
			return ItemDetailViewModel(repository: parent.itemRepository, item: item)
		}
		var featuresDemoViewModel: FeaturesDemoViewModel {
			registry.requireOpen()
			return parent.featuresDemoViewModel
		}
		var loggedInCoordinator: LoggedInCoordinator {
			registry.requireOpen()
			return LoggedInCoordinator(
				makeItemList: { self.itemListViewModel },
				makeItemDetail: { self.itemDetailViewModel(item: $0) },
				makeUser: { self.userTabViewModel },
				makeFeaturesDemo: { self.featuresDemoViewModel }
			)
		}
		func close() async { await registry.close() }
	}
#endif
