import Foundation

@MainActor
final class LoggedInFlow {
	let id = UUID()
	let coordinator: LoggedInCoordinator
	private let context: any LoggedInContextProtocol

	init(context: any LoggedInContextProtocol) {
		self.context = context
		self.coordinator = context.loggedInCoordinator
	}

	func close() async { await context.close() }
}
