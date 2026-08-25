import Foundation
import Testing
@testable import ZedChatLib

@Suite
struct ThreadContentClampingTests {
	@Test("clamping to a range within bounds returns just that range")
	func inRangeReturnsSubset() throws {
		let thread = try makeThread(messageCount: 5)

		let clamped = thread.clampingToMessageRange(1..<3)

		#expect(clamped.messages.count == 2)
		#expect(clamped.messageRange == 1..<3)
		#expect(clamped.messages[0].textContent.contains("message 1"))
		#expect(clamped.messages[1].textContent.contains("message 2"))
	}

	@Test("clamping to the full range returns all messages")
	func fullRangeReturnsAll() throws {
		let thread = try makeThread(messageCount: 5)

		let clamped = thread.clampingToMessageRange(0..<5)

		#expect(clamped.messages.count == 5)
		#expect(clamped.messageRange == 0..<5)
	}

	@Test("clamping to an empty range returns no messages")
	func emptyRangeReturnsNone() throws {
		let thread = try makeThread(messageCount: 5)

		let clamped = thread.clampingToMessageRange(2..<2)

		#expect(clamped.messages.isEmpty)
		#expect(clamped.messageRange == 2..<2)
	}

	private func makeThread(messageCount: Int) throws -> ThreadContent {
		let messages = (0..<messageCount).map { i in
			"{\"User\":{\"id\":\"m\(i)\",\"content\":[{\"Text\":\"message \(i)\"}]}}"
		}.joined(separator: ",")
		let json = """
			{"version":"0.3.0","updated_at":"2026-01-01T00:00:00.000000Z","messages":[\(messages)]}
			""".data(using: .utf8)!
		return try JSONDecoder().decode(ThreadContent.self, from: json)
	}
}
