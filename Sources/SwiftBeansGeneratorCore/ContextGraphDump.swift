import Foundation

/// Owner-qualified dumps consume the same visibility/injection plans as generated accessors.
enum ContextGraphDump {
	private struct Node {
		var provider: GraphProvider
		var dependencies: [GraphProvider]
		var storage: String { provider.inputType == nil ? provider.bean.scope.rawValue : "input" }
	}

	static func markdown(_ plans: [ContextCodePlan]) -> String {
		let nodes = nodes(plans)
		var lines = ["# SwiftBeans graph", "", "- Context: \(code(plans[0].context.name))"]
		for plan in plans where plan.parent != nil {
			lines.append("- Child: \(code(plan.context.name)) → \(code(plan.parent!.name))")
		}
		lines += [
			"- Providers: \(nodes.count)",
			"- Dependencies: \(nodes.reduce(0) { $0 + $1.dependencies.count })", "", "## Providers", "",
			"| Owner | Key | Accessor | Scope | Provided by | Assisted |", "|---|---|---|---|---|---|",
		]
		for node in nodes {
			let p = node.provider
			let arguments = p.bean.parameters.compactMap(\.assisted).map { ($0.label ?? "_") + ":" }
				.joined()
			lines.append(
				"| \(code(p.owner)) | \(code(p.bean.key.description)) | \(code(p.accessorName)) | \(node.storage) | \(code(p.bean.displayName)) | \(arguments.isEmpty ? "—" : code(arguments)) |"
			)
		}
		lines += ["", "## Dependencies", ""]
		let connected = nodes.filter { !$0.dependencies.isEmpty }
		if connected.isEmpty { lines.append("None.") }
		for node in connected {
			lines.append(
				"- \(code(identity(node.provider))) → \(node.dependencies.map { code(identity($0)) }.joined(separator: ", "))"
			)
		}
		return lines.joined(separator: "\n") + "\n"
	}

	static func dot(_ plans: [ContextCodePlan]) -> String {
		let nodes = nodes(plans)
		var lines = ["digraph SwiftBeans {", "\trankdir=LR;", "\tnode [shape=box, fontname=\"Helvetica\"];"]
		for node in nodes {
			let p = node.provider
			let label = "\(p.owner): \(p.bean.key)\n\(node.storage) · \(p.bean.displayName)"
			lines.append(
				"\t\(quoted(identity(p))) [label=\(quoted(label))\(p.bean.isAssisted ? ", style=dashed" : "")];"
			)
		}
		for node in nodes {
			for dependency in node.dependencies {
				lines.append("\t\(quoted(identity(node.provider))) -> \(quoted(identity(dependency)));")
			}
		}
		return (lines + ["}"]).joined(separator: "\n") + "\n"
	}

	private static func nodes(_ plans: [ContextCodePlan]) -> [Node] {
		plans.flatMap { plan in
			plan.own.map { provider in
				var targets: Set<ProviderID> = []
				for parameter in provider.bean.parameters where parameter.factory == nil {
					switch plan.bindings[parameter.location]?.injection {
					case .key(let key):
						if let target = plan.visible.first(where: {
							$0.bean.key == key && !$0.bean.isAssisted
						}) {
							targets.insert(target.id)
						}
					case .collection(let members):
						for member in members { targets.insert(plan.visible[member].id) }
					case nil: break
					}
				}
				return Node(
					provider: provider,
					dependencies: plan.visible.filter { targets.contains($0.id) }.sorted(by: less))
			}
		}.sorted { less($0.provider, $1.provider) }
	}

	private static func less(_ a: GraphProvider, _ b: GraphProvider) -> Bool {
		(a.owner, a.bean.key.description, a.bean.location) < (b.owner, b.bean.key.description, b.bean.location)
	}
	private static func identity(_ p: GraphProvider) -> String {
		String(
			data: try! JSONSerialization.data(
				withJSONObject: [p.owner, p.bean.key.description], options: [.withoutEscapingSlashes]),
			encoding: .utf8)!
	}
	private static func code(_ value: String) -> String {
		"`" + value.replacingOccurrences(of: "|", with: "\\|") + "`"
	}
	private static func quoted(_ value: String) -> String {
		"\""
			+ value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
				of: "\"", with: "\\\""
			).replacingOccurrences(of: "\n", with: "\\n") + "\""
	}
}
