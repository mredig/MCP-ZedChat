import MCP
import Foundation

extension ToolCommand {
	static let getThread = ToolCommand(rawValue: "zed-get-thread")
}

/// Tool for getting a specific Zed chat thread by ID
struct GetThreadTool: ToolImplementation {
	static let command: ToolCommand = .getThread
	
	static let tool = Tool(
		name: command.rawValue,
		description: "Get a specific Zed chat thread by ID",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"id": .object([
					"type": "string",
					"description": "The thread ID"
				]),
				"page": .object([
					"type": "integer",
					"description": "The output is paged to handle resources more efficiently. Defaults to `0` when omitted."
				]),
				"filters": .object([
					"type": "array",
					"description": "Filters to apply to the message output on the given thread. Notes: Filters are applied before paging, therefore consistent filtering should lead to consistent paging... Tho if filters are used, the `messageRange` property will be unreliable. Uses AND logic. `query` input is always caseInsensitive in this search.",
					"items": .object([
						"type": "object",
						"properties": .object([
							"type": .object([
								"type": "string",
								"enum": .array([
									.string("voice"),
									.string("query"),
									.string("isTool"),
									.string("isThinking"),
								])
							]),
							"value": .object([
								"type": "string",
								"description": "Value for filters that need one (like query). Valid values for each enum are:\nvoice: `agent` or `user`\nquery: any valid search query\nisTool: true/false\nisThinking: true/false"
							])
						]),
						"required": .array([.string("type"), .string("value")])
					])
				]),
			]),
			"required": .array([.string("id")])
		])
	)
	
	// Typed properties
	let id: String
	let page: Int
	let filters: [ThreadFilter]
	
	private let dbAccessor: ZedThreadsInterface
	
	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor
		
		guard let id = arguments.strings.id else {
			throw .missingArgument("id")
		}
		self.id = id
		self.page = arguments.integers.page ?? 0
		
		// Parse filters array
		let filtersArray = arguments.arguments?["filters"]?.arrayValue ?? []
		self.filters = filtersArray.compactMap { filterObjectContainer -> ThreadFilter? in
			guard
				let filterObject = filterObjectContainer.objectValue,
				let type = filterObject["type"]?.stringValue,
				let value = filterObject["value"]?.stringValue
			else { return nil }
			
			switch type {
			case "voice":
				switch value {
				case "user": return .voice(.user)
				case "agent": return .voice(.agent)
				default: return nil
				}
			case "query": return .query(value)
			case "isTool": return .isTool(Bool(value) ?? true)
			case "isThinking": return .isThinking(Bool(value) ?? true)
			default: return nil
			}
		}
	}
	
	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			let thread = try await dbAccessor.fetchThread(id: id)
			
			let messageRange = page..<(page+10)
			async let response = thread.consumableWithContent(withMessageRange: messageRange, andFilters: filters)
			
			let output = await StructuredContentOutput(
				inputRequest: "zed-get-thread: id: \(id) range: \(messageRange)",
				metaData: .init(summary: "Thread Details"),
				content: [response].compactMap(\.self))
			
			return output.toResult()
		} catch {
			throw .other(error)
		}
	}
}
