import Foundation

// MARK: - Zed Thread Models

/// Represents a complete Zed chat thread with all messages and metadata
struct ZedThread: Codable, Sendable {
	let title: String?
	let messages: [ZedThread.Message]
	let updatedAt: String
	let detailedSummary: String?
	let model: Model?
	let completionMode: String?
	let profile: String?
	let version: String?
	
	enum CodingKeys: String, CodingKey {
		case title
		case messages
		case updatedAt = "updated_at"
		case detailedSummary = "detailed_summary"
		case model
		case completionMode = "completion_mode"
		case profile
		case version
	}
}

extension ZedThread {
	struct Model: Codable, Sendable {
		let provider: String?
		let model: String?
	}
}

// MARK: - Message Types

extension ZedThread {
	/// A message in a Zed thread - can be from User or Agent
	enum Message: Codable, Sendable {
		case user(UserMessage)
		case agent(AgentMessage)

		struct UserMessage: Codable, Sendable {
			let id: String
			let content: [Content]
		}

		struct AgentMessage: Codable, Sendable {
			let content: [Content]
			//		let toolResults: [String: ToolResult]?

			enum CodingKeys: String, CodingKey {
				case content
				//			case toolResults = "tool_results"
			}
		}

		// Custom decoding to handle the User/Agent wrapper
		init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			let dict = try container.decode([String: AnyCodable].self)

			if let userData = dict["User"] {
				let userMsg = try userData.decode(UserMessage.self)
				self = .user(userMsg)
			} else if let agentData = dict["Agent"] {
				let agentMsg = try agentData.decode(AgentMessage.self)
				self = .agent(agentMsg)
			} else {
				throw DecodingError.dataCorruptedError(
					in: container,
					debugDescription: "Message must contain either 'User' or 'Agent' key"
				)
			}
		}

		func encode(to encoder: Encoder) throws {
			var container = encoder.singleValueContainer()
			switch self {
			case .user(let userMsg):
				try container.encode(["User": userMsg])
			case .agent(let agentMsg):
				try container.encode(["Agent": agentMsg])
			}
		}
	}
}

// MARK: - Message Content

extension ZedThread.Message {
	/// Content within a message - can be Text or ToolUse
	enum Content: Codable, Sendable {
		case text(String)
		case toolUse(ToolUse)
		case mention(Mention)
		case other(String)

		struct ToolUse: Codable, Sendable {
			let id: String
			let name: String
			let rawInput: String?
			let input: [String: AnyCodable]?

			enum CodingKeys: String, CodingKey {
				case id
				case name
				case rawInput = "raw_input"
				case input
			}
		}

		struct GenericKeys: CodingKey, Hashable {
			var stringValue: String

			init(stringValue: String) {
				self.stringValue = stringValue
				self.intValue = Int(stringValue)
			}

			var intValue: Int?

			init(intValue: Int) {
				self.intValue = intValue
				self.stringValue = "\(intValue)"
			}
		}

		struct Mention: Codable, Sendable {
			let uri: URIContainer
			let content: String

			struct URIContainer: Codable, Sendable {
				let file: File?
				let selection: Selection?

				enum CodingKeys: String, CodingKey {
					case file = "File"
					case selection = "Selection"
				}

				struct Selection: Codable, Sendable {
					let path: URL
					let range: Range<Int>

					init(path: URL, range: Range<Int>) {
						self.path = path
						self.range = range
					}

					init(from decoder: any Decoder) throws {
						let container = try decoder.container(keyedBy: CodingKeys.self)

						let path = try container.decode(String.self, forKey: .path)
						let rangeContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .range)

						let rangeStart = try rangeContainer.decode(Int.self, forKey: .start)
						let rangeEnd = try rangeContainer.decode(Int.self, forKey: .end)

						let range = rangeStart..<rangeEnd

						self.init(path: URL(filePath: path), range: range)
					}

					enum CodingKeys: String, CodingKey {
						case path = "abs_path"
						case range = "line_range"
						case start
						case end
					}

					func encode(to encoder: any Encoder) throws {
						var container = encoder.container(keyedBy: CodingKeys.self)
						try container.encode(path.path(percentEncoded: false), forKey: .path)

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

		init(from decoder: Decoder) throws {
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
			} else {
				throw DecodingError.dataCorruptedError(
					in: container,
					debugDescription: "MessageContent must contain either 'Text' or 'ToolUse' key"
				)
			}
		}

		func encode(to encoder: Encoder) throws {
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
			}
		}
	}
}

// MARK: - Tool Results

extension ZedThread {
	struct ToolResult: Codable, Sendable {
		let content: [Content]?
		let isError: Bool?

		enum CodingKeys: String, CodingKey {
			case content
			case isError = "is_error"
		}

		enum Content: Codable, Sendable {
			case text(String)
			case image(ImageContent)

			struct ImageContent: Codable, Sendable {
				let data: String
				let mimeType: String

				enum CodingKeys: String, CodingKey {
					case data
					case mimeType = "mime_type"
				}
			}

			init(from decoder: Decoder) throws {
				let container = try decoder.singleValueContainer()
				let dict = try container.decode([String: AnyCodable].self)

				if let text = dict["text"]?.value as? String {
					self = .text(text)
				} else if let imageData = dict["image"] {
					let image = try imageData.decode(ImageContent.self)
					self = .image(image)
				} else {
					throw DecodingError.dataCorruptedError(
						in: container,
						debugDescription: "ToolResultContent must contain either 'text' or 'image' key"
					)
				}
			}

			func encode(to encoder: Encoder) throws {
				var container = encoder.singleValueContainer()
				switch self {
				case .text(let text):
					try container.encode(["text": text])
				case .image(let image):
					try container.encode(["image": image])
				}
			}
		}
	}
}

// MARK: - Helper Type for Dynamic JSON

/// Type-erased wrapper for decoding heterogeneous JSON
struct AnyCodable: Codable, @unchecked Sendable {
	let value: Any
	
	init(_ value: Any) {
		self.value = value
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		
		if let bool = try? container.decode(Bool.self) {
			value = bool
		} else if let int = try? container.decode(Int.self) {
			value = int
		} else if let double = try? container.decode(Double.self) {
			value = double
		} else if let string = try? container.decode(String.self) {
			value = string
		} else if let array = try? container.decode([AnyCodable].self) {
			value = array.map(\.value)
		} else if let dict = try? container.decode([String: AnyCodable].self) {
			value = dict.mapValues(\.value)
		} else if container.decodeNil() {
			value = Optional<Any>.none as Any
		} else {
			throw DecodingError.dataCorruptedError(
				in: container,
				debugDescription: "Unable to decode value"
			)
		}
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		
		switch value {
		case let bool as Bool:
			try container.encode(bool)
		case let int as Int:
			try container.encode(int)
		case let double as Double:
			try container.encode(double)
		case let string as String:
			try container.encode(string)
		case let array as [Any]:
			try container.encode(array.map { AnyCodable($0) })
		case let dict as [String: Any]:
			try container.encode(dict.mapValues { AnyCodable($0) })
		default:
			if case Optional<Any>.none = value {
				try container.encodeNil()
			} else {
				throw EncodingError.invalidValue(
					value,
					EncodingError.Context(
						codingPath: encoder.codingPath,
						debugDescription: "Unable to encode value of type \(type(of: value))"
					)
				)
			}
		}
	}
	
	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		let data = try JSONEncoder().encode(self)
		return try JSONDecoder().decode(T.self, from: data)
	}
}

// MARK: - Convenience Extensions

extension ZedThread {
	/// Extract just the text content from all messages (for searching/display)
	var allTextContent: String {
		messages.compactMap { message in
			switch message {
			case .user(let userMsg):
				return userMsg.content.compactMap { content in
					if case .text(let text) = content {
						return text
					}
					return nil
				}.joined(separator: "\n")
			case .agent(let agentMsg):
				return agentMsg.content.compactMap { content in
					if case .text(let text) = content {
						return text
					}
					return nil
				}.joined(separator: "\n")
			}
		}.joined(separator: "\n\n")
	}
	
	/// Count of user messages
	var userMessageCount: Int {
		messages.filter {
			if case .user = $0 { return true }
			return false
		}.count
	}
	
	/// Count of agent messages
	var agentMessageCount: Int {
		messages.filter {
			if case .agent = $0 { return true }
			return false
		}.count
	}

	func nextMessage(containing query: String, caseInsensitive: Bool, startingFrom: Int? = nil) -> (index: Int, message: Message)? {
		let potential: [Message].SubSequence

		let regexQuery = Regex {
			query
		}
			.ignoresCase(caseInsensitive)

		if let startingFrom {
			let nextIndex = messages.index(after: startingFrom)
			guard messages.indices.contains(nextIndex) else { return nil }
			potential = messages[startingFrom..<messages.endIndex]
		} else {
			potential = messages[messages.startIndex..<messages.endIndex]
		}

		for index in potential.indices {
			let message = potential[index]
			let contents: [Message.Content]
			switch message {
			case .user(let userMessage):
				contents = userMessage.content
			case .agent(let agentMessage):
				contents = agentMessage.content
			}

			for content in contents {
				switch content {
				case .text(let text):
					guard text.contains(regexQuery) else { continue }
				case .mention(let mention):
					guard mention.content.contains(regexQuery) else { continue }
				case .toolUse(let toolUse):
					guard toolUse.rawInput?.contains(regexQuery) == true else { continue }
				case .other(let otherString):
					guard otherString.contains(regexQuery) else { continue }
				}
				return (index, message)
			}
		}

		return nil
	}

	func messages(containing query: String, caseInsensitive: Bool) -> [(index: Int, message: Message)] {
		var accumulator: [(Int, Message)] = []

		var startingOffset: Int? = nil
		while let result = nextMessage(containing: query, caseInsensitive: caseInsensitive, startingFrom: startingOffset) {
			accumulator.append(result)
			startingOffset = result.index
		}

		return accumulator
	}
}
