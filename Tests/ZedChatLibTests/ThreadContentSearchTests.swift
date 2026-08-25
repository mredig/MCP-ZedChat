import Foundation
import Testing
@testable import ZedChatLib

@Suite
struct ThreadContentSearchTests {
	@Test("finds a case-sensitive match at the correct index")
	func findsCaseSensitiveMatch() throws {
		let thread = try TestFixtures.decode("daylight_0.3.0")

		let result = thread.nextMessage(containing: "Daylight savings", caseInsensitive: false)

		// The user message contains lowercase "daylight savings"; only the agent
		// message has the capital-D form.
		#expect(result?.index == 1)
	}

	@Test("case-insensitive search finds different casing")
	func caseInsensitiveFindsDifferentCasing() throws {
		let thread = try TestFixtures.decode("daylight_0.3.0")

		let result = thread.nextMessage(containing: "sunday", caseInsensitive: true)

		#expect(result?.index == 0)
	}

	@Test("case-sensitive search misses different casing")
	func caseSensitiveMissesDifferentCasing() throws {
		let thread = try TestFixtures.decode("daylight_0.3.0")

		let result = thread.nextMessage(containing: "sunday", caseInsensitive: false)

		#expect(result == nil)
	}

	@Test("matches inside thinking content")
	func matchesInsideThinkingContent() throws {
		let thread = try TestFixtures.decode("jelly_beans_0.3.0")

		// Only present in message 1's thinking block, not in any Text content.
		let result = thread.nextMessage(containing: "asking for clarification first", caseInsensitive: false)

		#expect(result?.index == 1)
	}

	@Test("matches inside tool use raw input")
	func matchesInsideToolUseRawInput() throws {
		let thread = try TestFixtures.decode("jelly_beans_0.3.0")

		// Only present in message 4's ToolUse raw_input (the full LABEL.md payload),
		// not in any Text or Thinking content.
		let result = thread.nextMessage(containing: "avoiding unsolicited bean suggestions", caseInsensitive: false)

		#expect(result?.index == 4)
	}

	@Test("matches inside mention content")
	func matchesInsideMentionContent() throws {
		let thread = try TestFixtures.decode("hero_mad_libs_0.3.0")

		let result = thread.nextMessage(containing: "caped adventure", caseInsensitive: false)

		#expect(result?.index == 0)
	}

	@Test("startingFrom resumes the search after the given index")
	func startingFromResumesAfterGivenIndex() throws {
		let thread = try TestFixtures.decode("daylight_0.3.0")

		guard let first = thread.nextMessage(containing: "sunday", caseInsensitive: true) else {
			Issue.record("Expected a match for 'sunday'")
			return
		}
		guard let second = thread.nextMessage(containing: "sunday", caseInsensitive: true, startingFrom: first.index) else {
			Issue.record("Expected a second match for 'sunday'")
			return
		}

		#expect(first.index == 0)
		#expect(second.index == 1)
		#expect(thread.nextMessage(containing: "sunday", caseInsensitive: true, startingFrom: second.index) == nil)
	}

	@Test("no matches returns nil")
	func noMatchesReturnsNil() throws {
		let thread = try TestFixtures.decode("woodchuck-0.2.0")

		let result = thread.nextMessage(containing: "zzz-definitely-absent", caseInsensitive: true)

		#expect(result == nil)
	}

	@Test("messagesContaining does not report the same message twice")
	func messagesContainingDoesNotDuplicate() throws {
		let thread = try TestFixtures.decode("woodchuck-0.2.0")

		// Message 0 contains "woodchuck" twice; it must be reported once.
		let matches = thread.messages(containing: "woodchuck", caseInsensitive: false)
		let indices = matches.map(\.0)

		#expect(indices.contains(0))
		#expect(indices.count == Set(indices).count)
	}
}
