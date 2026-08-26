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

	@Test("an unknown version is misrouted to the legacy decoder")
	func unknownVersionMisroutesToLegacyDecoder() throws {
		let json = """
			{"version":"0.1.0","updated_at":"2026-01-01T00:00:00.000000Z","messages":[{"User":{"id":"u0","content":[{"Text":"hello"}]}}]}
			""".data(using: .utf8)!

		// The thread above is in 0.3.0 shape, but because the version is not
		// exactly "0.3.0" the decoder falls through to the legacy 0.2.0 shape
		// and fails on the legacy "role" field — an error that points at the
		// wrong problem. This test demonstrates (and pins) that misrouting.
		try expectLegacyMisrouting(from: json)
	}

	@Test("a missing version is misrouted to the legacy decoder")
	func missingVersionMisroutesToLegacyDecoder() throws {
		let json = """
		{"updated_at":"2026-01-01T00:00:00.000000Z","messages":[{"User":{"id":"u0","content":[{"Text":"hello"}]}}]}
		""".data(using: .utf8)!

		// Same misrouting: no version key means the legacy 0.2.0 path is taken.
		try expectLegacyMisrouting(from: json)
	}

	private func expectLegacyMisrouting(from json: Data) throws {
		do {
			_ = try JSONDecoder().decode(ThreadContent.self, from: json)
			Issue.record("Expected decoding to fail")
		} catch let error as DecodingError {
			guard case .keyNotFound(let key, _) = error else {
				Issue.record("Expected keyNotFound for the legacy 'role' field, got: \(error)")
				return
			}
			#expect(key.stringValue == "role", "The failure should point at the legacy 0.2.0 'role' field, proving the 0.3.0-shaped data was misrouted to the legacy decoder. Got: \(error)")
		} catch {
			Issue.record("Expected a DecodingError, got: \(error)")
		}
	}
}
