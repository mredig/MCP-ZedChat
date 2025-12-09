import MCP
import Foundation

extension ToolCommand {
	static let getMetadata = ToolCommand(rawValue: "zed-get-metadata")
}

/// Tool for retrieving metadata about Zed chat threads and messages
struct GetMetadataTool: ToolImplementation {
	static let command: ToolCommand = .getMetadata

	static let tool = Tool(
		name: command.rawValue,
		description: "Get metadata for a Zed chat thread or a specific message within a thread. Returns information such as message counts, roles, timestamps, model info, and content statistics without returning the full content.",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"threadID": .object([
					"type": "string",
					"description": "The thread ID"
				]),
				"messageIndex": .object([
					"type": "integer",
					"description": "Optional: The index of a specific message to get metadata for (0-based). If omitted, returns thread-level metadata."
				])
			]),
			"required": .array([.string("threadID")])
		])
	)

	// Typed properties
	let threadID: String
	let messageIndex: Int?

	private let dbAccessor: ZedThreadsInterface

	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor

		guard let threadID = arguments.strings.threadID else {
			throw .missingArgument("threadID")
		}
		self.threadID = threadID

		if let messageIndex = arguments.integers.messageIndex {
			guard messageIndex >= 0 else {
				throw .contentError(message: "messageIndex must be >= 0")
			}
			self.messageIndex = messageIndex
		} else {
			self.messageIndex = nil
		}
	}

	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			// Get the thread content (uses cache if available)
			guard
				let consumable = try await dbAccessor.fetchThreadWithContent(id: threadID),
				let zedThread = consumable.thread
			else { throw ContentError.contentError(message: "Failed to load thread content") }

			// If messageIndex is provided, return message metadata
			if let messageIndex = messageIndex {
				return try messageMetadata(for: messageIndex, in: zedThread, threadSummary: consumable.summary)
			} else {
				return try threadMetadata(for: zedThread, threadSummary: consumable.summary)
			}
		} catch let error as ContentError {
			throw error
		} catch {
			throw .other(error)
		}
	}

	/// Generate thread-level metadata
	private func threadMetadata(for thread: ZedThread, threadSummary: String) throws -> CallTool.Result {
		// Track message indices by type
		var userMessageIndices: [Int] = []
		var agentMessageIndices: [Int] = []
		var noopMessageIndices: [Int] = []
		var messagesWithToolsIndices: [Int] = []
		var messagesWithThinkingIndices: [Int] = []
		var totalTextLength = 0

		for (index, message) in thread.messages.enumerated() {
			switch message {
			case .user:
				userMessageIndices.append(index)
			case .agent(let agentMsg):
				agentMessageIndices.append(index)
				if agentMsg.toolResults != nil {
					messagesWithToolsIndices.append(index)
				}
				let hasThinking = agentMsg.content.contains { content in
					if case .thinking = content { return true }
					return false
				}
				if hasThinking {
					messagesWithThinkingIndices.append(index)
				}
			case .noop:
				noopMessageIndices.append(index)
			}

			totalTextLength += message.textContent.count
		}

		struct ThreadMetadata: Codable, Sendable {
			let threadID: String
			let threadSummary: String
			let title: String?
			let messageCount: Int
			let userMessageIndices: [Int]
			let agentMessageIndices: [Int]
			let noopMessageIndices: [Int]
			let messagesWithToolsIndices: [Int]
			let messagesWithThinkingIndices: [Int]
			let totalTextLength: Int
			let updatedAt: String
			let detailedSummary: String?
			let model: ModelInfo?
			let completionMode: String?
			let profile: String?
			let version: String?

			struct ModelInfo: Codable, Sendable {
				let provider: String?
				let model: String?
			}
		}

		let metadata = ThreadMetadata(
			threadID: threadID,
			threadSummary: threadSummary,
			title: thread.title,
			messageCount: thread.messageCount,
			userMessageIndices: userMessageIndices,
			agentMessageIndices: agentMessageIndices,
			noopMessageIndices: noopMessageIndices,
			messagesWithToolsIndices: messagesWithToolsIndices,
			messagesWithThinkingIndices: messagesWithThinkingIndices,
			totalTextLength: totalTextLength,
			updatedAt: thread.updatedAt,
			detailedSummary: thread.detailedSummary,
			model: thread.model.map { ThreadMetadata.ModelInfo(provider: $0.provider, model: $0.model) },
			completionMode: thread.completionMode,
			profile: thread.profile,
			version: thread.version
		)

		let output = StructuredContentOutput(
			inputRequest: "zed-get-metadata: threadID: \(threadID)",
			metaData: .init(summary: "Thread Metadata"),
			content: [metadata])

		return output.toResult()
	}

	/// Generate message-level metadata
	private func messageMetadata(for index: Int, in thread: ZedThread, threadSummary: String) throws(ContentError) -> CallTool.Result {
		// Validate message index
		guard index < thread.messages.count else {
			throw ContentError.contentError(message: "messageIndex \(index) out of range (thread has \(thread.messages.count) messages)")
		}

		let message = thread.messages[index]

		// Extract metadata based on message type
		let role: String
		let messageID: String?
		let contentItems: [ContentItemMetadata]
		let toolResultsCount: Int

		switch message {
		case .user(let userMsg):
			role = "user"
			messageID = userMsg.id
			contentItems = userMsg.content.map { ContentItemMetadata(from: $0) }
			toolResultsCount = 0

		case .agent(let agentMsg):
			role = "assistant"
			messageID = nil
			contentItems = agentMsg.content.map { ContentItemMetadata(from: $0) }
			toolResultsCount = agentMsg.toolResults?.count ?? 0

		case .noop:
			role = "noop"
			messageID = nil
			contentItems = []
			toolResultsCount = 0
		}

		let textContent = message.textContent
		let textLength = textContent.count

		// Count content types
		var textCount = 0
		var toolUseCount = 0
		var mentionCount = 0
		var thinkingCount = 0
		var otherCount = 0

		for item in contentItems {
			switch item.type {
			case "text": textCount += 1
			case "toolUse": toolUseCount += 1
			case "mention": mentionCount += 1
			case "thinking": thinkingCount += 1
			case "other": otherCount += 1
			default: break
			}
		}

		struct MessageMetadata: Codable, Sendable {
			let threadID: String
			let threadSummary: String
			let messageIndex: Int
			let messageID: String?
			let role: String
			let textLength: Int
			let contentItemCount: Int
			let textContentCount: Int
			let toolUseCount: Int
			let mentionCount: Int
			let thinkingCount: Int
			let otherContentCount: Int
			let toolResultsCount: Int
			let contentItems: [ContentItemMetadata]
		}

		struct ContentItemMetadata: Codable, Sendable {
			let type: String
			let length: Int?
			let toolName: String?

			init(from content: ZedThread.Message.Content) {
				switch content {
				case .text(let text):
					self.type = "text"
					self.length = text.count
					self.toolName = nil
				case .toolUse(let toolUse):
					self.type = "toolUse"
					self.length = nil
					self.toolName = toolUse.name
				case .mention:
					self.type = "mention"
					self.length = nil
					self.toolName = nil
				case .thinking(let thinking):
					self.type = "thinking"
					self.length = thinking.text.count
					self.toolName = nil
				case .other(let desc):
					self.type = "other"
					self.length = desc.count
					self.toolName = nil
				}
			}
		}

		let metadata = MessageMetadata(
			threadID: threadID,
			threadSummary: threadSummary,
			messageIndex: index,
			messageID: messageID,
			role: role,
			textLength: textLength,
			contentItemCount: contentItems.count,
			textContentCount: textCount,
			toolUseCount: toolUseCount,
			mentionCount: mentionCount,
			thinkingCount: thinkingCount,
			otherContentCount: otherCount,
			toolResultsCount: toolResultsCount,
			contentItems: contentItems
		)

		let output = StructuredContentOutput(
			inputRequest: "zed-get-metadata: threadID: \(threadID), messageIndex: \(index)",
			metaData: .init(summary: "Message Metadata"),
			content: [metadata])

		return output.toResult()
	}
}
