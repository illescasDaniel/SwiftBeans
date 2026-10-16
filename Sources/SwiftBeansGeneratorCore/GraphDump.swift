import SwiftBeansSyntaxRules

/// Text dumps of the resolved bean graph (SPEC graph-dump).
///
/// Pure functions of the validated providers: nodes sorted by key, edges by `(from, to)`.
enum GraphDump {
	/// One provider as it appears in a dump.
	private struct Node {
		var key: String
		var accessor: String
		var scope: ScopeLiteral
		var displayName: String
		/// Runtime-argument selector parts (`item:`), or `nil` when not assisted.
		var assistedArguments: [String]?
		/// Keys of the providers this one injects, sorted and de-duplicated.
		var dependencies: [String]
	}

	static func markdown(context: ContextDecl?, providers: [BeanProvider]) -> String {
		let nodes = nodes(of: providers)
		let edgeCount = nodes.reduce(0) { $0 + $1.dependencies.count }

		var lines = [
			"# SwiftBeans graph",
			"",
			"- Context: \(context.map { "`\($0.name)`" } ?? "none")",
			"- Providers: \(nodes.count)",
			"- Dependencies: \(edgeCount)",
			"",
			"## Providers",
			"",
			"| Key | Accessor | Scope | Provided by | Assisted |",
			"|-----|----------|-------|-------------|----------|",
		]
		for node in nodes {
			let assisted = node.assistedArguments.map { "`\($0.joined())`" } ?? "—"
			lines.append("| \(code(node.key)) | \(code(node.accessor)) | \(node.scope.rawValue) | \(code(node.displayName)) | \(assisted) |")
		}
		lines += ["", "## Dependencies", ""]
		let withDependencies = nodes.filter { !$0.dependencies.isEmpty }
		if withDependencies.isEmpty {
			lines.append("None.")
		}
		for node in withDependencies {
			lines.append("- \(code(node.key)) → \(node.dependencies.map(code).joined(separator: ", "))")
		}
		return lines.joined(separator: "\n") + "\n"
	}

	static func dot(providers: [BeanProvider]) -> String {
		var lines = [
			"digraph SwiftBeans {",
			"\trankdir=LR;",
			"\tnode [shape=box, fontname=\"Helvetica\"];",
		]
		let nodes = nodes(of: providers)
		for node in nodes {
			var label = "\(node.key)\n\(node.scope.rawValue) · \(node.displayName)"
			var attributes = ""
			if let arguments = node.assistedArguments {
				label += "\nassisted (\(arguments.joined()))"
				attributes = ", style=dashed"
			}
			lines.append("\t\(quoted(node.key)) [label=\(quoted(label))\(attributes)];")
		}
		for node in nodes {
			for dependency in node.dependencies {
				lines.append("\t\(quoted(node.key)) -> \(quoted(dependency));")
			}
		}
		lines.append("}")
		return lines.joined(separator: "\n") + "\n"
	}

	private static func nodes(of providers: [BeanProvider]) -> [Node] {
		let sorted = providers.sorted { ($0.key.description, $0.location) < ($1.key.description, $1.location) }
		let provided = Set(sorted.map(\.key))
		return sorted.map { provider in
			let dependencies = Set(
				provider.parameters.compactMap { parameter -> BeanKey? in
					guard parameter.assisted == nil, let key = parameter.key, provided.contains(key) else { return nil }
					return key
				}
			)
			return Node(
				key: provider.key.description,
				accessor: provider.key.accessorName.replacing("`", with: ""),
				scope: provider.scope,
				displayName: provider.displayName,
				assistedArguments: provider.isAssisted
					? provider.parameters.compactMap(\.assisted).map { "\($0.label ?? "_"):" }
					: nil,
				dependencies: dependencies.map(\.description).sorted()
			)
		}
	}

	/// Inline code that survives a `|` in a Markdown table cell.
	private static func code(_ text: String) -> String {
		"`\(text.replacing("|", with: "\\|"))`"
	}

	private static func quoted(_ text: String) -> String {
		let escaped = text
			.replacing("\\", with: "\\\\")
			.replacing("\"", with: "\\\"")
			.replacing("\n", with: "\\n")
		return "\"\(escaped)\""
	}
}
