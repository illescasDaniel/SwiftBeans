import SwiftBeansMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Child context macro contracts")
struct ChildContextMacroTests {
	@Test
	func `Given a child with ordered inputs When expanded Then parent storage and labelled initializer are added`()
	{
		assertMacroExpansion(
			"""
			@ChildContext(of: AppContext.self)
			final class SessionContext {
				@ContextInput let currentUser: User
				@ContextInput let credentials: SessionCredentials
			}
			""",
			expandedSource: """
				final class SessionContext {
					let currentUser: User
					let credentials: SessionCredentials

					let _swiftBeansRegistry = SwiftBeansRegistry()

					let _swiftBeansParent: any AppContextProtocol

					init(parent: any AppContextProtocol, currentUser: User, credentials: SessionCredentials) {
						self._swiftBeansParent = parent
						self.currentUser = currentUser
						self.credentials = credentials
					}
				}
				""",
			macroSpecs: [
				"ChildContext": MacroSpec(type: ChildContextMacro.self),
				"ContextInput": MacroSpec(type: ContextInputMacro.self),
			],
			indentationWidth: .tabs(1),
			failureHandler: { Issue.record("\($0.message)") }
		)
	}
	@Test
	func `Given a nested ordinary class When an input marker expands Then an outer child does not grant ownership`()
	{
		assertMacroExpansion(
			"""
			@ChildContext(of: AppContext.self)
			final class Session {
				final class Ordinary {
					@ContextInput let user: User
				}
			}
			""",
			expandedSource: """
				@ChildContext(of: AppContext.self)
				final class Session {
					final class Ordinary {
						let user: User
					}
				}
				""",
			diagnostics: [
				DiagnosticSpec(
					message: "@ContextInput is only supported inside @ChildContext", line: 4,
					column: 3)
			],
			macroSpecs: ["ContextInput": MacroSpec(type: ContextInputMacro.self)],
			indentationWidth: .tabs(1),
			failureHandler: { Issue.record("\($0.message)") }
		)
	}

}
