import SwiftBeans

/// One graph per successful login. The app flow awaits close at logout/expiry.
@MainActor
@ChildContext(of: AppContext.self, teardown: .managed)
final class LoggedInContext {
	@ContextInput let credentials: SessionCredentials
}
