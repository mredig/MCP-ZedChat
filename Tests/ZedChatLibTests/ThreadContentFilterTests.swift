import Foundation
import Testing
@testable import ZedChatLib

@Suite
struct ThreadContentFilterTests {
	@Test("voice(.user) keeps only user messages")
	func voiceUser() throws {
		let filtered = try TestFixtures.decode("hero_mad_libs_0.3.0").addingFilter(.voice(.user))

		#expect(filtered.messages.count == 8)
		#expect(filtered.messages.allSatisfy { isUser($0) })
	}

	@Test("voice(.agent) keeps only agent messages")
	func voiceAgent() throws {
		let filtered = try TestFixtures.decode("hero_mad_libs_0.3.0").addingFilter(.voice(.agent))

		#expect(filtered.messages.count == 12)
		#expect(filtered.messages.allSatisfy { isAgent($0) })
	}

	@Test("isThinking(true) keeps agent messages with thinking content")
	func isThinkingTrue() throws {
		let filtered = try TestFixtures.decode("jelly_beans_0.3.0").addingFilter(.isThinking(true))

		#expect(filtered.messages.count == 2)
		#expect(filtered.messages.allSatisfy { hasThinking($0) })
	}

	@Test("isThinking(false) keeps agent messages without thinking content")
	func isThinkingFalse() throws {
		let filtered = try TestFixtures.decode("jelly_beans_0.3.0").addingFilter(.isThinking(false))

		#expect(filtered.messages.count == 2)
		#expect(filtered.messages.allSatisfy { !hasThinking($0) })
	}

	@Test("isTool(true) matches every agent message whose tool_results decodes non-nil")
	func isToolTrue() throws {
		let filtered = try TestFixtures.decode("hero_mad_libs_0.3.0").addingFilter(.isTool(true))

		// Pinned behavior: every agent in this fixture has a "tool_results" key, and
		// even an empty {} decodes as a non-nil empty dictionary — so all 12 agents
		// match, not just the 4 that have actual results.
		#expect(filtered.messages.count == 12)
		#expect(filtered.messages.allSatisfy { isAgent($0) })
	}

	@Test("isTool(false) matches agents without a tool_results key")
	func isToolFalse() throws {
		let json = """
			{"version":"0.3.0","updated_at":"2026-01-01T00:00:00.000000Z","messages":[
				{"User":{"id":"u0","content":[{"Text":"a user message"}]}},
				{"Agent":{"content":[{"Text":"no tools"}]}},
				{"Agent":{"content":[{"Text":"with tools"}],"tool_results":{"t1":{"tool_use_id":"t1","tool_name":"echo","content":[{"Text":"ok"}],"is_error":false}}}}
			]}
			""".data(using: .utf8)!

		let thread = try JSONDecoder().decode(ThreadContent.self, from: json)
		let filtered = thread.addingFilter(.isTool(false))

		// The user message is dropped (the filter only considers agents), as is the
		// agent that has a tool_results key.
		#expect(filtered.messages.count == 1)
		#expect(filtered.messages[0].textContent == "Agent: no tools")
	}

	private func isUser(_ message: ThreadContent.Message) -> Bool {
		if case .user = message { return true }
		return false
	}

	private func isAgent(_ message: ThreadContent.Message) -> Bool {
		if case .agent = message { return true }
		return false
	}

	private func hasThinking(_ message: ThreadContent.Message) -> Bool {
		guard case .agent(let agent) = message else { return false }
		return agent.content.contains {
			if case .thinking = $0 { return true }
			return false
		}
	}
}
