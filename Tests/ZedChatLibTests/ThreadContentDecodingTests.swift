import Foundation
import Testing
import ZedChatLib

@Suite
struct ThreadContentDecodingTests {
	// each of these files had some encoding issue that tripped up previous versions of the model. they are kept around
	// for tests to eliminate recurrance
	private static let fixtures: [String] = [
		"daylight_0.3.0",
		"hero_mad_libs_0.3.0",
		"jelly_beans_0.3.0",
		"woodchuck_0.2.0",
		"best_bear_0.3.0",
		"trek_vs_wars_0.3.0",
	]

	private static let expectedVersions: [String: String] = [
		"daylight_0.3.0": "0.3.0",
		"hero_mad_libs_0.3.0": "0.3.0",
		"jelly_beans_0.3.0": "0.3.0",
		"woodchuck_0.2.0": "0.2.0",
		"best_bear_0.3.0": "0.3.0",
		"trek_vs_wars_0.3.0": "0.3.0",
	]

	@Test(arguments: fixtures)
	func decodesThreadContent(fileName: String) throws {
		guard let url = Bundle.module.url(
			forResource: fileName,
			withExtension: "json",
			subdirectory: "Resources") else {
			Issue.record("Missing fixture: \(fileName).json")
			return
		}
		let data = try Data(contentsOf: url)

		let thread = try JSONDecoder().decode(ThreadContent.self, from: data)

		#expect(thread.version == Self.expectedVersions[fileName])
		#expect(!thread.messages.isEmpty)
		#expect(thread.messageCount == thread.messages.count)
		#expect(!thread.updatedAt.isEmpty)
	}
}
