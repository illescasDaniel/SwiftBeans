import SwiftUI

/// Explains why `@Configuration` / `@Bean` matter: wiring HTTIES + URLSession/fake.
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

			Section("Graph") {
				LabeledContent("@Bean") {
					Text("httpDataRequestHandler")
						.font(.caption.monospaced())
				}
				LabeledContent("@Bean") {
					Text("httpClient(handler:)")
						.font(.caption.monospaced())
				}
				LabeledContent("@Service(boundTo:)") {
					Text("JSONPlaceholderItemRepository")
						.font(.caption.monospaced())
				}
				Text("DEBUG builds use `FakeJSONPlaceholderDataHandler`; other builds use `URLSession.shared` for live jsonplaceholder.typicode.com.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("Active handler bean") {
				LabeledContent("Type") {
					Text(viewModel.handlerDescription)
						.font(.caption.monospaced())
				}
			}

			Section("Generator coverage") {
				Text(viewModel.welcomeBannerMessage)
				Text("Nested `Features.WelcomeBanner` ← `any Greeter` from local package `GreetingKitLive` (auto-imported) + `TagSummary` (`@Inject` init taking `Dictionary<String, Int>` from a `[String: Int]` `@Bean`).")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("HTTIES request") {
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
		.navigationTitle("HTTIES + @Bean")
	}
}

#if DEBUG
#Preview("FeaturesDemoView") {
	let context = FakeAppContext()
	NavigationStack {
		FeaturesDemoView(viewModel: context.featuresDemoViewModel)
	}
}
#endif
