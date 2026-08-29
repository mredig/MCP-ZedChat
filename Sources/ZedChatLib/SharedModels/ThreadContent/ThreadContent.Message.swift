extension ThreadContent {
	/// A message in a Zed thread - can be from User or Agent
	public enum Message: Codable, Sendable {
		case user(UserMessage)
		case agent(AgentMessage)
		case compaction(CompactionSummary)
		case noop

		public var role: String {
			switch self {
			case .user:
				"user"
			case .agent:
				"assistant"
			case .compaction:
				"compaction"
			case .noop:
				"noop"
			}
		}

		public struct CompactionSummary: Codable, Sendable {
			public let summary: String
		}

		public struct UserMessage: Codable, Sendable {
			public let id: String
			public let content: [Content]

			public var wrappedContent: [Content.Wrapper] {
				content.map { .init(context: "User", content: $0) }
			}
		}

		public struct AgentMessage: Codable, Sendable {
			public let content: [Content]
			public let toolResults: [String: ToolResult]?

			public var wrappedContent: [Content.Wrapper] {
				var accumulator: [Content.Wrapper] = content.map {
					.init(context: "Agent", content: $0)
				}

				guard let toolResults else {
					return accumulator
				}

				for (_, tool) in toolResults {
					accumulator.append(.init(context: "\nToolID", content: .text(tool.toolUseID)))
					guard let content = tool.content else {
						let errorString = {
							guard let isError = tool.isError else {
								return "unknown"
							}
							return "\(isError)"
						}()
						accumulator.append(.init(context: "\nToolError", content: .text(errorString)))
						continue
					}
					if let toolName = tool.toolName {
						accumulator.append(.init(context: "\nToolName", content: .text(toolName)))
					}
					for item in content {
						switch item {
						case .text(let string):
							accumulator.append(.init(context: "\nToolContent", content: .text(string)))
						case .image:
							accumulator.append(.init(context: "\nToolContent", content: .other("Generated Image - Unable to render in text")))
						}
					}
				}
				return accumulator
			}

			enum CodingKeys: String, CodingKey {
				case content
				case toolResults = "tool_results"
			}
		}

		// Custom decoding to handle the User/Agent wrapper
		public init(from decoder: Decoder) throws {
			let container = try decoder.singleValueContainer()
			let dict: [String: AnyCodable]
			do {
				dict = try container.decode([String: AnyCodable].self)
			} catch DecodingError.typeMismatch(let expectedType, _) where expectedType == [String: Any].self {
				_ = try container.decode(String.self)

				self = .noop
				return
			}

			if let userData = dict["User"] {
				let userMsg = try userData.decode(UserMessage.self)
				self = .user(userMsg)
			} else if let agentData = dict["Agent"] {
				let agentMsg = try agentData.decode(AgentMessage.self)
				self = .agent(agentMsg)
			} else if let compaction = dict["Compaction"] {
				guard
					let compactionDict = compaction.value as? [String: String],
					let summary = compactionDict["Summary"] else {
					throw DecodingError.dataCorruptedError(in: container, debugDescription: "Compaction summary missing summary key")
				}
				self = .compaction(CompactionSummary(summary: summary))
			} else {
				let errorMessage = "Message must contain either 'User' or 'Agent' key"
				throw DecodingError.dataCorruptedError(
					in: container,
					debugDescription: errorMessage)
			}
		}

		public func encode(to encoder: Encoder) throws {
			var container = encoder.singleValueContainer()
			switch self {
			case .user(let userMsg):
				try container.encode(["User": userMsg])
			case .agent(let agentMsg):
				try container.encode(["Agent": agentMsg])
			case .compaction(let compaction):
				try container.encode(["Compaction": ["Summary": compaction.summary]])
			case .noop: break
			}
		}
		
		/// Extract all text content from the message (for searching/display)
		public var textContent: String {
			let content: [Content.Wrapper]
			switch self {
			case .user(let userMsg):
				content = userMsg.wrappedContent
			case .agent(let agentMsg):
				content = agentMsg.wrappedContent
			case .compaction(let summary):
				content = [Content.Wrapper(context: "Compaction", content: .compactionSummary(summary.summary))]
			case .noop:
				return ""
			}
			
			return content.compactMap { item -> String? in
				switch item.content {
				case .text(let text):
					return "\(item.context): \(text)"
				case .thinking(let thinking):
					return "\(item.context): \(thinking.text)"
				case .toolUse(let toolUse):
					return "\(item.context): \(toolUse.description)"
				case .mention, .other, .image:
					return nil
				}
			}.joined(separator: " ")
		}

		public func contains(query: String, caseInsensitive: Bool) -> Bool {
			let searchOptions: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
			let contents: [Message.Content]
			switch self {
			case .user(let userMessage):
				contents = userMessage.content
			case .agent(let agentMessage):
				contents = agentMessage.content
			case .compaction(let compactSummary):
				contents = [.compactionSummary(compactSummary.summary)]
			case .noop:
				return false
			}

			for content in contents {
				switch content {
				case .text(let text):
					guard text.range(of: query, options: searchOptions) != nil else { continue }
				case .mention(let mention):
					guard mention.content.range(of: query, options: searchOptions) != nil else { continue }
				case .toolUse(let toolUse):
					guard toolUse.rawInput?.range(of: query, options: searchOptions) != nil else { continue }
				case .other(let otherString):
					guard otherString.range(of: query, options: searchOptions) != nil else { continue }
				case .thinking(let thinking):
					guard thinking.text.range(of: query, options: searchOptions) != nil else { continue }
				case .image:
					continue
				}
				return true
			}

			return false
		}
	}
}
