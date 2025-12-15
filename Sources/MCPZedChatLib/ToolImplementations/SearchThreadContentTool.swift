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
		description: "Search Zed chat threads by decoding their thread content and searching inside. Returns matches with limited context (~100 characters before and after the match) to reduce token usage. Use the returned messageIndex with zed-get-message to retrieve the full message if needed. Can optionally scope search to specific threads or exclude specific threads. NOTE: The current conversation that is driving this search is NOT automatically excluded from the results — callers must either ignore that thread in the returned results or explicitly exclude it (for example by using `scopeToThreadIDs` with `excludeThreadIDs` once the thread ID is known).",
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
				]),
				"scopeToThreadIDs": .object([
					"type": "array",
					"items": .object([
						"type": "string"
					]),
					"description": "Optional array of thread IDs to limit the search to. If provided with excludeThreadIDs=false (default), only these threads will be searched. If provided with excludeThreadIDs=true, these threads will be excluded from search."
				]),
				"excludeThreadIDs": .object([
					"type": "boolean",
					"description": "When false (default), scopeToThreadIDs acts as an inclusion list (only search these threads). When true, scopeToThreadIDs acts as an exclusion list (search all threads except these). Ignored if scopeToThreadIDs is not provided. TIP: It's good practice to exclude the current thread ID (once identified) to avoid finding matches in the current conversation."
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
	let scopedThreadIDs: Set<String>?
	let shouldExcludeThreadIDs: Bool

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

		// Extract array of thread IDs from arguments
		if let arrayValue = arguments.arguments?["scopeToThreadIDs"]?.arrayValue {
			self.scopedThreadIDs = arrayValue.compactMap(\.stringValue).reduce(into: .init(), { $0.insert($1) })
		} else {
			self.scopedThreadIDs = nil
		}

		self.shouldExcludeThreadIDs = arguments.bools.excludeThreadIDs ?? false
	}

	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			let threadResults = try await dbAccessor.searchThreadContent(
				for: query,
				caseInsensitive: caseInsensitive,
				page: page,
				onlyFirstMatchPerThread: onlyFirstMatchPerThread,
				scopedThreadIDs: scopedThreadIDs,
				excludeThreadIDs: shouldExcludeThreadIDs)

			let scopeDescription = scopedThreadIDs.map { ids in
				shouldExcludeThreadIDs ? "excluding \(ids.count) thread(s)" : "limited to \(ids.count) thread(s)"
			} ?? "all threads"

			let output = StructuredContentOutput(
				inputRequest: "zed-search-thread-content: query: \(query), page: \(page), caseInsensitive: \(caseInsensitive), onlyFirstMatchPerThread: \(onlyFirstMatchPerThread), scope: \(scopeDescription)",
				metaData: .init(summary: "Thread Content Search Results", resultCount: threadResults.count),
				content: threadResults)

			return output.toResult()
		} catch {
			throw .other(error)
		}
	}
}
