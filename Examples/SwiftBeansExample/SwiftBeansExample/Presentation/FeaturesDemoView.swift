import SwiftUI

/// Live readout of the graph: foreign beans, qualifiers, named services, collections, factories.
struct FeaturesDemoView: View {
	@State private var viewModel: FeaturesDemoViewModel

	init(viewModel: FeaturesDemoViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	private var isLoading: Bool {
		viewModel.state == .loading
	}

	private var statusText: String {
		switch viewModel.state {
		case .idle: "Tap fetch to load post #1"
		case .loading: "GET /posts/1 via HTTIES…"
		case .loaded: "OK — post loaded"
		case .failed(let message): "Request failed: \(message)"
		}
	}

	var body: some View {
		List {
			Section("Why @Bean?") {
				Text(
					"HTTIES’ `HTTPClient` and Foundation’s `URLSession` aren’t your types — you can’t put `@Service` on them. `@Configuration` + `@Bean` factory methods register those foreign dependencies in the graph."
				)
				.font(.footnote)
			}

			Section("@Qualifier") {
				Text("Two `JSONDecoder` beans and two `Greeter`s. Unqualified parameters get the unnamed bean; `@Qualifier` picks the named one.")
					.font(.footnote)
					.foregroundStyle(.secondary)
				LabeledContent("snake_case title") {
					Text(viewModel.snakeCaseTitle)
						.font(.caption.monospaced())
				}
				LabeledContent("Greeter") {
					Text(viewModel.standardGreeting)
						.font(.caption.monospaced())
				}
				LabeledContent("@Qualifier(\"short\")") {
					Text(viewModel.shortGreeting)
						.font(.caption.monospaced())
				}
			}

			Section("@Service(named:)") {
				Text("`StaticTagSource` is `@Service(named: \"builtin\")`. `RemoteTagSource` is `@Service(boundTo: TagSource.self, named: \"remote\")`.")
					.font(.footnote)
					.foregroundStyle(.secondary)
				LabeledContent("builtin") {
					Text(viewModel.builtinTagLabel)
						.font(.caption.monospaced())
				}
				LabeledContent("remote") {
					Text(viewModel.remoteTagLabel)
						.font(.caption.monospaced())
				}
			}

			Section("Collections") {
				Text("`[any FeatureNote]` is every bean that declares `FeatureNote`, in accessor-name order.")
					.font(.footnote)
					.foregroundStyle(.secondary)
				ForEach(viewModel.featureNotes, id: \.title) { note in
					VStack(alignment: .leading, spacing: 4) {
						Text(note.title)
							.font(.headline)
						Text(note.detail)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}
			}

			Section("Factories") {
				Text("This screen's view model came from `() -> FeaturesDemoViewModel`. `AppCoordinator` also takes `() -> ItemListViewModel` and `(Item) -> ItemDetailViewModel`, and it never holds the context.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("Generator coverage") {
				Text(viewModel.welcomeBannerMessage)
				Text("Nested `Features.WelcomeBanner` ← `any Greeter` from local package `GreetingKitLive` (auto-imported) + `TagSummary` (`@Inject` init taking `Dictionary<String, Int>` from a `[String: Int]` `@Bean`).")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("HTTIES request") {
				LabeledContent("Handler") {
					Text(viewModel.handlerDescription)
						.font(.caption.monospaced())
				}
				Text("DEBUG builds use `FakeJSONPlaceholderDataHandler`; other builds use `URLSession.shared` for live jsonplaceholder.typicode.com. The repository decodes with the unqualified `JSONDecoder`.")
					.font(.footnote)
					.foregroundStyle(.secondary)
				if isLoading {
					ProgressView()
				}
				if let title = viewModel.sampleTitle {
					Text(title)
						.font(.headline)
				}
				Text(statusText)
					.font(.footnote)
					.foregroundStyle(.secondary)
				Button("Fetch post #1") {
					Task { await viewModel.fetchSamplePost() }
				}
				.disabled(isLoading)
			}
		}
		.navigationTitle("SwiftBeans features")
	}
}

#if DEBUG
#Preview("FeaturesDemoView") {
	let context = FakeAppContext()
	PreviewRootView(coordinator: context.appCoordinator) {
		FeaturesDemoView(viewModel: context.featuresDemoViewModel)
	}
}
#endif
