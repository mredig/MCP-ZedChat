import Foundation
import Testing
@testable import ZedChatLib

@Suite
struct ThreadContentFilterTests {
	@Test("voice(.user) keeps only user messages")
	func voiceUser() throws {
		let content = try TestFixtures.decode("hero_mad_libs_0.3.0")
		let indicies = content.messageIndicies(with: .voice(.user))

		#expect(indicies.count == 8)
		for index in indicies {
			let message = content.messages[index]
			#expect(isUser(message))
		}
	}

	@Test("voice(.agent) keeps only agent messages")
	func voiceAgent() throws {
		let content = try TestFixtures.decode("hero_mad_libs_0.3.0")
		let indicies = content.messageIndicies(with: .voice(.agent))

		#expect(indicies.count == 12)
		for index in indicies {
			let message = content.messages[index]
			#expect(isAgent(message))
		}
	}

	@Test("isThinking(true) keeps agent messages with thinking content")
	func isThinkingTrue() throws {
		let content = try TestFixtures.decode("jelly_beans_0.3.0")
		let indicies = content.messageIndicies(with: .isThinking(true))

		#expect(indicies.count == 2)
		for index in indicies {
			let message = content.messages[index]
			#expect(hasThinking(message))
		}
	}

	@Test("isThinking(false) keeps agent messages without thinking content")
	func isThinkingFalse() throws {
		let content = try TestFixtures.decode("jelly_beans_0.3.0")
		let indicies = content.messageIndicies(with: .isThinking(false))

		#expect(indicies.count == 2)
		for index in indicies {
			let message = content.messages[index]
			#expect(hasThinking(message) == false)
		}
	}

	@Test("isTool(true) matches every agent message whose tool_results decodes non-nil")
	func isToolTrue() throws {
		let content = try TestFixtures.decode("hero_mad_libs_0.3.0")
		let indicies = content.messageIndicies(with: .isTool(true))

		// Pinned behavior: every agent in this fixture has a "tool_results" key, and
		// even an empty {} decodes as a non-nil empty dictionary — so all 12 agents
		// match, not just the 4 that have actual results.
		#expect(indicies.count == 12)
		for index in indicies {
			let message = content.messages[index]
			#expect(isAgent(message))
		}
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
		let indicies = thread.messageIndicies(with: .isTool(false))

		// The user message is dropped (the filter only considers agents), as is the
		// agent that has a tool_results key.
		#expect(indicies.count == 1)
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
