
/// Represents a complete Zed chat thread with all messages and metadata
public struct ThreadContent: Codable, Sendable {
	public let title: String?
	public private(set) var messages: [ThreadContent.Message]
	public let messageCount: Int
	public private(set) var messageRange: Range<Int>?
	public let updatedAt: String
	public let detailedSummary: String?
	public let model: Model?
	public let completionMode: String?
	public let profile: String?
	public let version: String?

	@available(*, deprecated)
	private(set) var filters: [ThreadFilter] = []

	public init(title: String?, messages: [ThreadContent.Message], updatedAt: String, detailedSummary: String?, model: Model?, completionMode: String?, profile: String?, version: String?) {
		self.title = title
		self.messages = messages
		self.messageCount = messages.count
		self.updatedAt = updatedAt
		self.detailedSummary = detailedSummary
		self.model = model
		self.completionMode = completionMode
		self.profile = profile
		self.version = version
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		let version = try container.decodeIfPresent(String.self, forKey: .version)
		let title = try container.decodeIfPresent(String.self, forKey: .title)
		let updatedAt = try container.decode(String.self, forKey: .updatedAt)
		let detailedSummary = try container.decodeIfPresent(String.self, forKey: .detailedSummary)
		let model = try container.decodeIfPresent(ThreadContent.Model.self, forKey: .model)
		let completionMode = try container.decodeIfPresent(String.self, forKey: .completionMode)
		let profile = try container.decodeIfPresent(String.self, forKey: .profile)

		do {
			let messages: [ThreadContent.Message]
			if version == "0.3.0" {
				messages = try container.decode([ThreadContent.Message].self, forKey: .messages)
			} else {
				let oldMessages = try container.decode([Legacy.ZedThreadMessage_0_2_0].self, forKey: .messages)
				messages = oldMessages.map { $0.toVersion0_3_0() }
			}

			self.init(
				title: title,
				messages: messages,
				updatedAt: updatedAt,
				detailedSummary: detailedSummary,
				model: model,
				completionMode: completionMode,
				profile: profile,
				version: version)
		} catch {
			throw error
		}
	}

	public func messageIndicies(with filter: ThreadFilter) -> [Int] {
		messages.enumerated().reduce([]) {
			switch filter {
			case .voice(let voice):
				switch voice {
				case .agent:
					guard case .agent = $1.element else { return $0 }
					return $0 + [$1.offset]
				case .user:
					guard case .user = $1.element else { return $0 }
					return $0 + [$1.offset]
				}
			case .query(let string, let caseInsensitive):
				guard $1.element.contains(query: string, caseInsensitive: caseInsensitive) else {
					return $0
				}
				return $0 + [$1.offset]
			case .isTool(let flag):
				guard
					case .agent(let agentMessage) = $1.element
				else { return $0 }
				let isTool = agentMessage.toolResults != nil
				if flag == isTool {
					return $0 + [$1.offset]
				} else {
					return $0
				}
			case .isThinking(let flag):
				guard
					case .agent(let agentMessage) = $1.element
				else { return $0 }

				let hasThinking = agentMessage.content.contains { messageContent in
					guard case .thinking = messageContent else { return false }
					return true
				}

				if hasThinking == flag {
					return $0 + [$1.offset]
				} else {
					return $0
				}
			}
		}
	}

	@available(*, deprecated)
	func addingFilter(_ filter: ThreadFilter) -> ThreadContent {
		var new = self

		new.filters.append(filter)

		switch filter {
		case .voice(let voice):
			switch voice {
			case .agent:
				new.messages = new.messages.filter {
					guard case .agent = $0 else { return false }
					return true
				}
			case .user:
				new.messages = new.messages.filter {
					guard case .user = $0 else { return false }
					return true
				}
			}
		case .query(let query, _):
			new.messages = new.messages(containing: query, caseInsensitive: true).map(\.message)
		case .isTool(let isTool):
			new.messages = new.messages.filter {
				guard case .agent(let agentMessage) = $0 else { return false }
				return (agentMessage.toolResults != nil) == isTool
			}
		case .isThinking(let isThinking):
			new.messages = new.messages.filter {
				guard case .agent(let agentMessage) = $0 else { return false }

				let hasThinking = agentMessage.content.contains { messageContent in
					guard case .thinking = messageContent else { return false }
					return true
				}

				return hasThinking == isThinking
			}
		}

		return new
	}

	struct UnsupportedVersionError: Error {}

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

extension ThreadContent {
	/// Extract just the text content from all messages (for searching/display)
	var allTextContent: String {
		messages.compactMap { message in
			switch message {
			case .noop:
				return ""
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
			case .compaction(let compactSummary):
				return compactSummary.summary
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

		if let startingFrom {
			let nextIndex = messages.index(after: startingFrom)
			guard messages.indices.contains(nextIndex) else { return nil }
			potential = messages[nextIndex..<messages.endIndex]
		} else {
			potential = messages[messages.startIndex..<messages.endIndex]
		}

		for index in potential.indices {
			let message = potential[index]

			guard message.contains(query: query, caseInsensitive: caseInsensitive) else{
				continue
			}
			return (index, message)
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
