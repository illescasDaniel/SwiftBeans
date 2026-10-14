import SwiftUI

/// Explains why `@Configuration` / `@Bean` matter: wiring HTTIES + URLSession/fake.
struct FeaturesDemoView: View {
	@Bindable var viewModel: FeaturesDemoViewModel
	let container: any AppContextProtocol

	@State private var handlerA: ObjectIdentifier?
	@State private var handlerB: ObjectIdentifier?

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
				Text("Default handler is `FakeJSONPlaceholderDataHandler`. Change the bean to `URLSession.shared` for live jsonplaceholder.typicode.com.")
					.font(.footnote)
					.foregroundStyle(.secondary)
			}

			Section("Singleton handler (class)") {
				Button("Resolve httpDataRequestHandler twice") {
					handlerA = ObjectIdentifier(container.httpDataRequestHandler as AnyObject)
					handlerB = ObjectIdentifier(container.httpDataRequestHandler as AnyObject)
				}
				if let handlerA, let handlerB {
					LabeledContent("Same instance?") {
						Text(handlerA == handlerB ? "yes ✓" : "no ✗")
							.foregroundStyle(handlerA == handlerB ? .green : .red)
					}
				}
			}

			Section("HTTIES request") {
				if viewModel.isLoading {
					ProgressView()
				}
				if let title = viewModel.sampleTitle {
					Text(title)
						.font(.headline)
				}
				Text(viewModel.statusText)
					.font(.footnote)
					.foregroundStyle(.secondary)
				Button("Fetch post #1") {
					Task { await viewModel.fetchSamplePost() }
				}
				.disabled(viewModel.isLoading)
			}
		}
		.navigationTitle("HTTIES + @Bean")
	}
}

#Preview("FeaturesDemoView") {
	let context = FakeAppContext()
	NavigationStack {
		FeaturesDemoView(
			viewModel: context.featuresDemoViewModel,
			container: context
		)
	}
}
