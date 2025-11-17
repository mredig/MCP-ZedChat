import MCP
import Foundation

extension ToolCommand {
	static let listThreads = ToolCommand(rawValue: "zed-list-threads")
}

/// Tool for listing all Zed chat threads from the threads database
struct ListThreadsTool: ToolImplementation {
	static let command: ToolCommand = .listThreads
	
	static let tool = Tool(
		name: command.rawValue,
		description: "List all Zed chat threads from the threads database",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"limit": .object([
					"type": "integer",
					"description": "Limit result count"
				])
			])
		])
	)
	
	// Typed properties
	let limit: Int?
	
	private let dbAccessor: ZedThreadsInterface
	
	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor
		self.limit = arguments.integers.limit
	}
	
	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			let threads = try await dbAccessor.fetchAllThreads(limit: limit)
			async let consumableThreads = threads.asyncConcurrentMap { await $0.consumable }
			
			let output = await StructuredContentOutput(
				inputRequest: "zed-list-threads\(limit.map { " (limit: \($0))" } ?? "")",
				metaData: .init(resultCount: threads.count),
				content: consumableThreads)
			
			return output.toResult()
		} catch {
			throw .other(error)
		}
	}
}
