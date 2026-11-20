import Observation
import SwiftBeans

@Service(in: LoggedInContext.self, scope: .transient, autoInit: true)
@Observable
@MainActor
final class UserTabViewModel {
	let repository: UserRepository
}
