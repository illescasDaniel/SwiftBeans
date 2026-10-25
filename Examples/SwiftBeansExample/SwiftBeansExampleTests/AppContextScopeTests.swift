import HTTIES
import Testing
@testable import SwiftBeansExample

@Suite("AppContext scopes")
@MainActor
struct AppContextScopeTests {
	@Test
	func `Given singleton handler When resolved twice Then same instance`() {
		let context = AppContext()
		let first = instanceID(of: context.httpDataRequestHandler)
		let second = instanceID(of: context.httpDataRequestHandler)
		#expect(first == second)
	}

	@Test
	func `Given transient view models When resolved twice Then distinct instances`() {
		let context = LoggedInContext(parent: AppContext(), credentials: .preview)
		let first = context.itemListViewModel
		let second = context.itemListViewModel
		#expect(first !== second)
	}

	@Test
	func `Given assisted detail view model When called twice Then new instances carry their items`() {
		let context = LoggedInContext(parent: AppContext(), credentials: .preview)
		let first = context.itemDetailViewModel(item: Item(id: 1, title: "One", detail: "A"))
		let second = context.itemDetailViewModel(item: Item(id: 2, title: "Two", detail: "B"))
		#expect(first !== second)
		#expect(first.item.id == 1)
		#expect(second.item.id == 2)
	}

	@Test
	func `Given protocol binding When resolving itemRepository Then returns JSONPlaceholder repository`() {
		let context = AppContext()
		#expect(context.itemRepository is JSONPlaceholderItemRepository)
	}

	@Test
	func `Given configuration beans When fetching posts Then returns fake JSONPlaceholder data`() async throws {
		let context = AppContext()
		let items = try await context.itemRepository.fetchItems()
		#expect(items.count == 5)
		#expect(items.first?.id == 1)
	}
	@Test func `Given user tab model factory When resolved Then the logged in repository is shared and closes`() async {
		let parent = AppContext()
		let context = LoggedInContext(parent: parent, credentials: .preview)
		let first = context.userTabViewModel
		let second = context.userTabViewModel
		#expect(first !== second)
		#expect(first.repository === context.userRepository)
		#expect(second.repository === first.repository)
		#expect(first.repository.catalog as AnyObject === parent.itemRepository as AnyObject)
		await context.close()
		#expect(first.repository.isClosed)
	}

	@Test func `Given two child contexts When one closes Then the parent array and sibling session remain usable`() async {
		let parent = AppContext()
		let first = LoggedInContext(parent: parent, credentials: .preview)
		let second = LoggedInContext(parent: parent, credentials: .preview)
		let firstRepository = first.userRepository
		let secondRepository = second.userRepository
		let firstModel = parent.featuresDemoViewModel
		let secondModel = parent.featuresDemoViewModel
		#expect(firstRepository !== secondRepository)
		#expect(first.userTabViewModel.repository === firstRepository)
		#expect(second.userTabViewModel.repository === secondRepository)
		for model in [firstModel, secondModel] {
			#expect(model.highlightedNotes.map(\.title) == ["Factories", "@Assisted"])
			#expect(model.highlightedNotes.first as? FactoryFeatureNote === parent.factoryFeatureNote)
			#expect(model.highlightedNotes.last as? AssistedFeatureNote === parent.assistedFeatureNote)
		}
		await first.close()
		#expect(firstRepository.isClosed)
		#expect(!secondRepository.isClosed)
		let stillOpen = parent.featuresDemoViewModel
		#expect(second.userTabViewModel.repository === secondRepository)
		#expect(stillOpen.highlightedNotes.first as? FactoryFeatureNote === parent.factoryFeatureNote)
		#expect(parent.highlightsFeatureNoteArray.last as? AssistedFeatureNote === parent.assistedFeatureNote)
		await second.close()
		#expect(secondRepository.isClosed)
	}

}
