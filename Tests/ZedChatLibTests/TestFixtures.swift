import Foundation
import ZedChatLib

enum TestFixtures {
	enum MissingFixture: Error {
		case missing(String)
	}

	static func url(for name: String) -> URL? {
		Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources")
	}

	static func decode(_ name: String) throws -> ThreadContent {
		guard let url = url(for: name) else {
			throw MissingFixture.missing(name)
		}
		return try JSONDecoder().decode(ThreadContent.self, from: Data(contentsOf: url))
	}
}
