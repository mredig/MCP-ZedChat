import MCP
import Foundation

extension ToolCommand {
	static let searchThreads = ToolCommand(rawValue: "zed-search-threads")
}

/// Tool for searching Zed chat threads by summary text
struct SearchThreadsTool: ToolImplementation {
	static let command: ToolCommand = .searchThreads
	
	static let tool = Tool(
		name: command.rawValue,
		description: "Search Zed chat threads by summary text",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"query": .object([
					"type": "string",
					"description": "Search query to match against thread summaries"
				]),
				"limit": .object([
					"type": "integer",
					"description": "Limit result count"
				])
			]),
			"required": .array([.string("query")])
		])
	)
	
	// Typed properties
	let query: String
	let limit: Int?
	
	private let dbAccessor: ZedThreadsInterface
	
	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor
		
		guard let query = arguments.strings.query else {
			throw .missingArgument("query")
		}
		self.query = query
		self.limit = arguments.integers.limit
	}
	
	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			let threadResults = try dbAccessor.searchThreadTitles(for: query, limit: limit)
			async let consumableThreadResults = threadResults.asyncConcurrentMap { await $0.consumable }
			
			let output = await StructuredContentOutput(
				inputRequest: "zed-search-threads: query: \(query)\(limit.map { " limit: \($0)" } ?? "")",
				metaData: .init(summary: "Thread Titles Search Results", resultCount: threadResults.count),
				content: consumableThreadResults)
			
			return output.toResult()
		} catch {
			throw .other(error)
		}
	}
}
