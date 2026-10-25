import Foundation
import Observation
import SwiftBeans

/// Session-owned repository sharing the app's catalog repository across logins.
@Service(in: LoggedInContext.self)
@Observable
@MainActor
final class UserRepository: ContextCleanup {
	let credentials: SessionCredentials
	let catalog: any ItemRepository
	private(set) var heartbeatCount = 0
	private(set) var isClosed = false
	@ObservationIgnored private var work: Task<Void, Never>?

	init(credentials: SessionCredentials, catalog: any ItemRepository) {
		self.credentials = credentials
		self.catalog = catalog
		work = Task { @MainActor [weak self] in
			while !Task.isCancelled {
				do { try await Task.sleep(for: .seconds(1)) } catch { return }
				guard self != nil else { return }
				self?.heartbeatCount += 1
			}
		}
	}

	func close() async {
		guard !isClosed else { return }
		isClosed = true
		let pending = work
		work = nil
		pending?.cancel()
		await pending?.value
	}

	deinit { work?.cancel() }
}
