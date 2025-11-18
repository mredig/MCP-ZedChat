import MCP
import Foundation

extension ToolCommand {
	static let getMessage = ToolCommand(rawValue: "zed-get-message")
}

/// Tool for getting a specific message from a Zed chat thread with character-level pagination
struct GetMessageTool: ToolImplementation {
	static let command: ToolCommand = .getMessage
	
	static let tool = Tool(
		name: command.rawValue,
		description: "Get a specific message from a Zed chat thread by its index. Returns paginated character content from the message to reduce token usage. Use offset and limit parameters to navigate through large messages.",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"threadID": .object([
					"type": "string",
					"description": "The thread ID"
				]),
				"messageIndex": .object([
					"type": "integer",
					"description": "The index of the message within the thread (0-based)"
				]),
				"offset": .object([
					"type": "integer",
					"description": "Starting character position within the message (default: 0)"
				]),
				"limit": .object([
					"type": "integer",
					"description": "Maximum number of characters to return (default: 1000)"
				])
			]),
			"required": .array([.string("threadID"), .string("messageIndex")])
		])
	)
	
	// Typed properties
	let threadID: String
	let messageIndex: Int
	let offset: Int
	let limit: Int
	
	private let dbAccessor: ZedThreadsInterface
	
	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor
		
		guard let threadID = arguments.strings.threadID else {
			throw .missingArgument("threadID")
		}
		self.threadID = threadID
		
		guard let messageIndex = arguments.integers.messageIndex else {
			throw .missingArgument("messageIndex")
		}
		guard messageIndex >= 0 else {
			throw .contentError(message: "messageIndex must be >= 0")
		}
		self.messageIndex = messageIndex
		
		self.offset = arguments.integers.offset ?? 0
		guard self.offset >= 0 else {
			throw .contentError(message: "offset must be >= 0")
		}
		
		self.limit = arguments.integers.limit ?? 1000
		guard self.limit > 0 else {
			throw .contentError(message: "limit must be > 0")
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

			// Validate message index
			guard messageIndex < zedThread.messages.count else {
				throw ContentError.contentError(message: "messageIndex \(messageIndex) out of range (thread has \(zedThread.messages.count) messages)")
			}
			
			// Get the specific message
			let message = zedThread.messages[messageIndex]
			
			// Extract text content
			let fullText = message.textContent
			let totalLength = fullText.count
			
			// Determine message role and ID
			let role: String
			let messageID: String?
			switch message {
			case .user(let userMsg):
				role = "user"
				messageID = userMsg.id
			case .agent:
				role = "assistant"
				messageID = nil
			case .noop:
				role = "noop"
				messageID = nil
			}
			
			// Apply pagination
			let startIndex = fullText.index(fullText.startIndex, offsetBy: min(offset, totalLength), limitedBy: fullText.endIndex) ?? fullText.endIndex
			let endOffset = min(offset + limit, totalLength)
			let endIndex = fullText.index(fullText.startIndex, offsetBy: endOffset, limitedBy: fullText.endIndex) ?? fullText.endIndex
			
			let contentSlice = String(fullText[startIndex..<endIndex])
			let hasMore = endOffset < totalLength
			
			struct MessageContent: Codable, Sendable {
				let threadID: String
				let threadSummary: String
				let messageIndex: Int
				let messageID: String?
				let role: String
				let content: String
				let totalLength: Int
				let returnedLength: Int
				let offset: Int
				let hasMore: Bool
				let nextOffset: Int?
			}
			
			let messageContent = MessageContent(
				threadID: threadID,
				threadSummary: consumable.summary,
				messageIndex: messageIndex,
				messageID: messageID,
				role: role,
				content: contentSlice,
				totalLength: totalLength,
				returnedLength: contentSlice.count,
				offset: offset,
				hasMore: hasMore,
				nextOffset: hasMore ? endOffset : nil
			)
			
			let output = StructuredContentOutput(
				inputRequest: "zed-get-message: threadID: \(threadID), messageIndex: \(messageIndex), offset: \(offset), limit: \(limit)",
				metaData: .init(summary: "Message Content"),
				content: [messageContent])
			
			return output.toResult()
		} catch let error as ContentError {
			throw error
		} catch {
			throw .other(error)
		}
	}
}
