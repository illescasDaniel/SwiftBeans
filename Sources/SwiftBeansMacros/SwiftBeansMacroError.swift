import SwiftDiagnostics
import SwiftSyntax

enum SwiftBeansMacroError: Error, CustomStringConvertible {
	case message(String)

	var description: String {
		switch self {
		case .message(let text):
			return text
		}
	}
}
