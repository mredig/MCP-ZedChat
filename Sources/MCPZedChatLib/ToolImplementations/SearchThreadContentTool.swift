import MCP
import Foundation

extension ToolCommand {
	static let searchThreadContent = ToolCommand(rawValue: "zed-search-thread-content")
}

/// Tool for searching Zed chat threads by decoding their thread content and searching inside
struct SearchThreadContentTool: ToolImplementation {
	static let command: ToolCommand = .searchThreadContent
	
	static let tool = Tool(
		name: command.rawValue,
		description: "Search Zed chat threads by decoding their thread content and searching inside",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"query": .object([
					"type": "string",
					"description": "Search query to match against thread summaries. There's no special syntax. Matches must be exact (apart from case sensitivity, specified in another argument)"
				]),
				"page": .object([
					"type": "integer",
					"description": "Results are paged because they can be obscenely large. This allows for more efficient, bite sized search. If omitted, defaults to `0`"
				]),
				"caseInsensitive": .object([
					"type": "boolean",
					"description": "Whether the query matching is case sensitive"
				]),
				"onlyFirstMatchPerThread": .object([
					"type": "boolean",
					"description": "When true, message filtering will stop on a thread once a message is found with a match. When false, all matching messages on the thread will be returned. It is more efficient to set to true, when exhaustion isn't necessary."
				])
			]),
			"required": .array([.string("query")])
		])
	)
	
	// Typed properties
	let query: String
	let page: Int
	let caseInsensitive: Bool
	let onlyFirstMatchPerThread: Bool
	
	private let dbAccessor: ZedThreadsInterface
	
	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor
		
		guard let query = arguments.strings.query else {
			throw .missingArgument("query")
		}
		self.query = query
		self.page = arguments.integers.page ?? 0
		self.caseInsensitive = arguments.bools.caseInsensitive ?? true
		self.onlyFirstMatchPerThread = arguments.bools.onlyFirstMatchPerThread ?? false
	}
	
	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			let threadResults = try await dbAccessor.searchThreadContent(
				for: query,
				caseInsensitive: caseInsensitive,
				page: page,
				onlyFirstMatchPerThread: onlyFirstMatchPerThread)
			
			let output = StructuredContentOutput(
				inputRequest: "zed-search-thread-content: query: \(query), page: \(page), caseInsensitive: \(caseInsensitive), onlyFirstMatchPerThread: \(onlyFirstMatchPerThread)",
				metaData: .init(summary: "Thread Content Search Results", resultCount: threadResults.count),
				content: threadResults)
			
			return output.toResult()
		} catch {
			throw .other(error)
		}
	}
}