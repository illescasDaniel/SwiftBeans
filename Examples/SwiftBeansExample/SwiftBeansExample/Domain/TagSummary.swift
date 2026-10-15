import SwiftBeans

/// Two initializers: `@Inject` selects the one the generated context calls.
///
/// The other (`init(tags:)`) needs `[String]`, which the graph does not provide,
/// so picking it would fail the build.
@Service
final class TagSummary: Sendable {
	let tagCounts: [String: Int]

	@Inject
	init(tagCounts: Dictionary<String, Int>) {
		self.tagCounts = tagCounts
	}

	convenience init(tags: [String]) {
		self.init(tagCounts: Dictionary(tags.map { ($0, 1) }, uniquingKeysWith: +))
	}

	/// Tags sorted by count (descending), then name.
	var topTags: [String] {
		tagCounts
			.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
			.map(\.key)
	}
}
