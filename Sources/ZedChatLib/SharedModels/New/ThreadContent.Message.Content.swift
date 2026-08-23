import Foundation

extension ThreadContent.Message {
	/// Content within a message - can be Text or ToolUse
	public enum Content: Codable, Sendable {
		case text(String)
		case toolUse(ToolUse)
		case mention(Mention)
		case thinking(Thinking)
		case other(String)

		public struct Wrapper: Codable, Sendable {
			public let context: String
			public let content: Content
		}

		public struct Thinking: Codable, Sendable {
			public let text: String
			public let signature: String?
		}

		public struct ToolUse: Codable, Sendable, CustomStringConvertible {
			public let id: String
			public let name: String
			public let rawInput: String?
			public let input: [String: AnyCodable]?

			public var description: String {
				var accumulator: [String] = []

				accumulator.append(name)
				accumulator.append("(\(id))")

				if let rawInput {
					accumulator.append("`\(rawInput)`")
				} else if let input {
					accumulator.append("\(input)")
				}

				return accumulator.joined(separator: " ")
			}

			enum CodingKeys: String, CodingKey {
				case id
				case name
				case rawInput = "raw_input"
				case input
			}
		}

		public struct Mention: Codable, Sendable {
			public let uri: URIContainer
			public let content: String

			public struct URIContainer: Codable, Sendable {
				let file: File?
				let selection: Selection?

				enum CodingKeys: String, CodingKey {
					case file = "File"
					case selection = "Selection"
				}

				public struct Selection: Codable, Sendable {
					public let path: URL?
					public let range: Range<Int>

					public init(path: URL?, range: Range<Int>) {
						self.path = path
						self.range = range
					}

					public init(from decoder: any Decoder) throws {
						let container = try decoder.container(keyedBy: CodingKeys.self)

						let path = try container.decodeIfPresent(String.self, forKey: .path)
						let rangeContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .range)

						let rangeStart = try rangeContainer.decode(Int.self, forKey: .start)
						let rangeEnd = try rangeContainer.decode(Int.self, forKey: .end)

						let range = rangeStart..<rangeEnd

						self.init(path: path.map { URL(filePath: $0) }, range: range)
					}

					enum CodingKeys: String, CodingKey {
						case path = "abs_path"
						case range = "line_range"
						case start
						case end
					}

					public func encode(to encoder: any Encoder) throws {
						var container = encoder.container(keyedBy: CodingKeys.self)
						try container.encodeIfPresent(path?.path(percentEncoded: false), forKey: .path)

						var lineRangeContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .range)
						try lineRangeContainer.encode(range.lowerBound, forKey: .start)
						try lineRangeContainer.encode(range.upperBound, forKey: .end)
					}
				}

				struct File: Codable, Sendable {
					let path: URL

					enum CodingKeys: String, CodingKey {
						case path = "abs_path"
					}

					init(path: URL) {
						self.path = path
					}

					init(from decoder: any Decoder) throws {
						let container = try decoder.container(keyedBy: CodingKeys.self)
						let pathStr = try container.decode(String.self, forKey: .path)

						self.init(path: URL(filePath: pathStr))
					}

					func encode(to encoder: any Encoder) throws {
						var container = encoder.container(keyedBy: CodingKeys.self)
						try container.encode(path.path(percentEncoded: false), forKey: .path)
					}
				}
			}
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			let dict = try container.decode([String: AnyCodable].self)

			if let text = dict["Text"]?.value as? String {
				self = .text(text)
			} else if let toolUseData = dict["ToolUse"] {
				let toolUse = try toolUseData.decode(ToolUse.self)
				self = .toolUse(toolUse)
			} else if let mentionData = dict["Mention"] {
				let mention = try mentionData.decode(Mention.self)
				self = .mention(mention)
			} else if let thinkingdata = dict["Thinking"] {
				let thinking = try thinkingdata.decode(Thinking.self)
				self = .thinking(thinking)
			} else {
				throw DecodingError.dataCorruptedError(
					in: container,
					debugDescription: "MessageContent must contain either 'Text' or 'ToolUse' key")
			}
		}

		public func encode(to encoder: Encoder) throws {
			var container = encoder.singleValueContainer()
			switch self {
			case .text(let text):
				try container.encode(["Text": text])
			case .toolUse(let toolUse):
				try container.encode(["ToolUse": toolUse])
			case .mention(let mention):
				try container.encode(["Mention": mention])
			case .other(let otherText):
				try container.encode(["Other": otherText])
			case .thinking(let thinking):
				try container.encode(["Thinking": thinking])
			}
		}
	}
}
