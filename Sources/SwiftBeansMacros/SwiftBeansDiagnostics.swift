import SwiftBeansSyntaxRules
import SwiftDiagnostics
import SwiftSyntaxMacros

/// A `Violation` as a compiler error.
struct ViolationMessage: DiagnosticMessage {
	var violation: Violation

	var message: String { violation.message }
	var diagnosticID: MessageID { MessageID(domain: "SwiftBeans", id: violation.id) }
	var severity: DiagnosticSeverity { .error }
}

extension MacroExpansionContext {
	/// Reports each violation at its node.
	func diagnose(_ violations: [Violation]) {
		for violation in violations {
			diagnose(Diagnostic(node: violation.node, message: ViolationMessage(violation: violation)))
		}
	}
}
