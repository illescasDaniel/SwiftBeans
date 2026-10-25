import Observation
import SwiftBeans

@Service(in: LoggedInContext.self, scope: .transient)
@Observable
@MainActor
final class UserTabViewModel {
	let repository: UserRepository
	init(repository: UserRepository) { self.repository = repository }
}
