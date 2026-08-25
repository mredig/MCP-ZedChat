import Foundation
import Testing
import ZedChatLib

@Suite
struct ThreadContentVersionDispatchTests {
	@Test("decodes a minimal 0.3.0 thread")
	func decodes030() throws {
		let json = """
			{"version":"0.3.0","updated_at":"2026-01-01T00:00:00.000000Z","messages":[{"User":{"id":"u0","content":[{"Text":"hello"}]}}]}
			""".data(using: .utf8)!

		let thread = try JSONDecoder().decode(ThreadContent.self, from: json)

		#expect(thread.version == "0.3.0")
		#expect(thread.messageCount == 1)
	}

	@Test("decodes a minimal 0.2.0 thread via the legacy path")
	func decodes020() throws {
		let json = """
			{"version":"0.2.0","updated_at":"2026-01-01T00:00:00.000000Z","messages":[{"role":"user","segments":[{"type":"text","text":"hello"}],"tool_uses":[],"tool_results":[]}]}
			""".data(using: .utf8)!

		let thread = try JSONDecoder().decode(ThreadContent.self, from: json)

		#expect(thread.version == "0.2.0")
		#expect(thread.messageCount == 1)
	}

	@Test("an unknown version throws instead of silently misdecoding")
	func unknownVersionThrows() throws {
		let json = """
			{"version":"0.1.0","updated_at":"2026-01-01T00:00:00.000000Z","messages":[{"User":{"id":"u0","content":[{"Text":"hello"}]}}]}
			""".data(using: .utf8)!

		#expect(throws: Error.self) {
			_ = try JSONDecoder().decode(ThreadContent.self, from: json)
		}
	}

	@Test("a missing version currently throws (pinned behavior)")
	func missingVersionThrows() throws {
		let json = """
			{"updated_at":"2026-01-01T00:00:00.000000Z","messages":[{"User":{"id":"u0","content":[{"Text":"hello"}]}}]}
			""".data(using: .utf8)!

		// Pinned: without a version key the decoder falls through to the legacy
		// 0.2.0 path and fails on the missing "role". If the dispatch is ever
		// changed, this test should be revisited deliberately.
		#expect(throws: Error.self) {
			_ = try JSONDecoder().decode(ThreadContent.self, from: json)
		}
	}
}
