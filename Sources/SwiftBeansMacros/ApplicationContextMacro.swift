import SwiftBeansSyntaxRules
import SwiftSyntax
import SwiftSyntaxMacros

/// Adds the `_swiftBeansRegistry` singleton storage to an `@ApplicationContext` class.
public struct ApplicationContextMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		let violations = SwiftBeansSyntaxRules.applicationContextViolations(declaration, attribute: node)
		guard violations.isEmpty else {
			context.diagnose(violations)
			return []
		}
		// Internal (same-module) so generated extensions in other files can use it.
		return [
			"let _swiftBeansRegistry = SwiftBeansRegistry()",
		]
	}
}
