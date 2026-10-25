// Phase 2 hand-written consumer shape for type checking, not generator/behavior tests.
// Compile with -module-name ChildContractConsumer for the identity witness below.
import SwiftBeansContracts

final class Transport {}

protocol AppContextProtocol: AnyObject {
	var transport: Transport { get }
}

final class AppContext: AppContextProtocol {
	let transport = Transport()
}

final class FakeAppContext: AppContextProtocol {
	let transport = Transport()
}

struct SessionCredentials {
	let userID: Int
}

struct Item {
	let id: Int
}

@MainActor
protocol UserRepository: AnyObject {}

@MainActor
final class LiveUserRepository: UserRepository, ContextCleanup {
	init(transport: Transport, credentials: SessionCredentials) {}
	func close() async {}
}

@MainActor
final class UserTabViewModel {
	init(repository: any UserRepository) {}
}

@MainActor
final class DetailViewModel {
	init(repository: any UserRepository, item: Item) {}
}

@MainActor
final class LoggedInCoordinator {
	let makeUser: @MainActor () -> UserTabViewModel
	let makeDetail: @MainActor (Item) -> DetailViewModel
	let makeTransport: @MainActor () -> Transport
	let makeAsyncUser: @MainActor () async -> UserTabViewModel

	init(
		makeUser: @escaping @MainActor () -> UserTabViewModel,
		makeDetail: @escaping @MainActor (Item) -> DetailViewModel,
		makeTransport: @escaping @MainActor () -> Transport,
		makeAsyncUser: @escaping @MainActor () async -> UserTabViewModel
	) {
		self.makeUser = makeUser
		self.makeDetail = makeDetail
		self.makeTransport = makeTransport
		self.makeAsyncUser = makeAsyncUser
	}
}

@MainActor
protocol LoggedInContextProtocol: AnyObject {
	var credentials: SessionCredentials { get }
	var userRepository: any UserRepository { get }
	var userTabViewModel: UserTabViewModel { get }
	var loggedInCoordinator: LoggedInCoordinator { get }
	func detailViewModel(item: Item) -> DetailViewModel
	func close() async
}

@MainActor
final class LoggedInContext {
	let credentials: SessionCredentials
	let _swiftBeansParent: any AppContextProtocol
	let _swiftBeansRegistry = SwiftBeansManagedRegistry(contextName: "LoggedInContext")

	init(parent: any AppContextProtocol, credentials: SessionCredentials) {
		self._swiftBeansParent = parent
		self.credentials = credentials
	}

	func close() async {
		await _swiftBeansRegistry.close()
	}
}

extension LoggedInContext: LoggedInContextProtocol {
	var userRepository: any UserRepository {
		_swiftBeansRegistry.singleton(key: "userRepository") {
			LiveUserRepository(transport: self._swiftBeansParent.transport, credentials: self.credentials)
		}
	}

	var userTabViewModel: UserTabViewModel {
		_swiftBeansRegistry.requireOpen()
		return UserTabViewModel(repository: self.userRepository)
	}

	func detailViewModel(item: Item) -> DetailViewModel {
		_swiftBeansRegistry.requireOpen()
		return DetailViewModel(repository: self.userRepository, item: item)
	}

	var loggedInCoordinator: LoggedInCoordinator {
		_swiftBeansRegistry.requireOpen()
		return LoggedInCoordinator(
			makeUser: { @MainActor in
				self._swiftBeansRegistry.requireOpen()
				return self.userTabViewModel
			},
			makeDetail: { @MainActor item in
				self._swiftBeansRegistry.requireOpen()
				return self.detailViewModel(item: item)
			},
			makeTransport: { @MainActor in
				self._swiftBeansRegistry.requireOpen()
				return self._swiftBeansParent.transport
			},
			makeAsyncUser: { @MainActor in
				self._swiftBeansRegistry.requireOpen()
				return self.userTabViewModel
			}
		)
	}
}

extension LoggedInContext {
	// Compile-time identity witness for a same-module-qualified of: reference.
	// This function is never called; the compiler still checks both conversions.
	private static func _swiftBeansValidateParentType() {
		let _: (ChildContractConsumer.AppContext) -> AppContext = { $0 }
		let _: (AppContext) -> ChildContractConsumer.AppContext = { $0 }
	}
}

@MainActor
final class FakeLoggedInContext: LoggedInContextProtocol {
	let credentials = SessionCredentials(userID: 1)
	var userRepository: any UserRepository { fatalError("Contract stub") }
	var userTabViewModel: UserTabViewModel { fatalError("Contract stub") }
	var loggedInCoordinator: LoggedInCoordinator { fatalError("Contract stub") }
	func detailViewModel(item: Item) -> DetailViewModel { fatalError("Contract stub") }
	func close() async {}
}

@MainActor
protocol MainActorAppContextProtocol: AnyObject {
	var transport: Transport { get }
}

@MainActor
final class FakeMainActorAppContext: MainActorAppContextProtocol {
	let transport = Transport()
}

@MainActor
final class MainActorParentChild {
	let parent: any MainActorAppContextProtocol
	let registry = SwiftBeansManagedRegistry(contextName: "MainActorParentChild")
	init(parent: any MainActorAppContextProtocol) { self.parent = parent }
	var userRepository: any UserRepository {
		registry.singleton(key: "userRepository") {
			LiveUserRepository(transport: self.parent.transport, credentials: .init(userID: 2))
		}
	}
}

@MainActor
func assembleContracts() async {
	let context = LoggedInContext(parent: FakeAppContext(), credentials: .init(userID: 1))
	let coordinator = context.loggedInCoordinator
	_ = coordinator.makeUser()
	_ = coordinator.makeDetail(.init(id: 1))
	_ = coordinator.makeTransport()
	_ = await coordinator.makeAsyncUser()
	let protocolValue: any LoggedInContextProtocol = context
	await protocolValue.close()
	let fake: any LoggedInContextProtocol = FakeLoggedInContext()
	await fake.close()
	_ = MainActorParentChild(parent: FakeMainActorAppContext()).userRepository
}
