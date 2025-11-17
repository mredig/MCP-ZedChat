import MCP
import Foundation

// MARK: - Structured Output Helper

struct StructuredContentOutput<Content: Codable & Sendable>: Codable, Sendable {
	let inputRequest: String
	let metaData: Metadata?
	let content: [Content]

	struct Metadata: Codable, Sendable {
		let summary: String?
		let resultCount: Int?

		init(summary: String? = nil, resultCount: Int? = nil) {
			self.summary = summary
			self.resultCount = resultCount
		}
	}

	func toResult() -> CallTool.Result {
		var accumulator: [Tool.Content] = []

		if let metaData {
			let jsonString = try? Self.encodeToJSONString(metaData)
			jsonString.map { accumulator.append(.text($0)) }
		}

		for item in content {
			let jsonString = try? Self.encodeToJSONString(item)
			jsonString.map { accumulator.append(.text($0)) }
		}

		return .init(content: accumulator, isError: false)
	}

	private static func encodeToJSONString<E: Encodable>(_ encodable: E) throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		encoder.dateEncodingStrategy = .iso8601
		let data = try encoder.encode(encodable)
		return String(decoding: data, as: UTF8.self)
	}
}

// MARK: - Content Error

enum ContentError: Error {
	case missingArgument(String)
	case mismatchedType(argument: String, expected: String)
	case initializationFailed(String)
	case contentError(message: String?)
	case other(Error)
}
