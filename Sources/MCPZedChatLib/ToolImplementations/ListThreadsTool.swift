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
		description: "List all Zed chat threads from the threads database. Threads can be filtered by date range based on their last update time.",
		inputSchema: .object([
			"type": "object",
			"properties": .object([
				"limit": .object([
					"type": "integer",
					"description": "Limit result count"
				]),
				"startDate": .object([
					"type": "string",
					"description": "Filter threads updated after this date (ISO 8601 format, e.g. '2024-01-01T00:00:00Z')"
				]),
				"endDate": .object([
					"type": "string",
					"description": "Filter threads updated before this date (ISO 8601 format, e.g. '2024-12-31T23:59:59Z')"
				])
			])
		])
	)
	
	// Typed properties
	let limit: Int?
	let startDate: Date?
	let endDate: Date?
	
	private let dbAccessor: ZedThreadsInterface
	
	/// Initialize and validate parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
		self.dbAccessor = dbAccessor
		self.limit = arguments.integers.limit
		
		// Parse date strings if provided
		let dateFormatter = ISO8601DateFormatter()
		if let startDateString = arguments.strings.startDate {
			guard let parsed = dateFormatter.date(from: startDateString) else {
				throw .contentError(message: "Invalid startDate format. Use ISO 8601 format (e.g. '2024-01-01T00:00:00Z')")
			}
			self.startDate = parsed
		} else {
			self.startDate = nil
		}
		
		if let endDateString = arguments.strings.endDate {
			guard let parsed = dateFormatter.date(from: endDateString) else {
				throw .contentError(message: "Invalid endDate format. Use ISO 8601 format (e.g. '2024-12-31T23:59:59Z')")
			}
			self.endDate = parsed
		} else {
			self.endDate = nil
		}
	}
	
	/// Execute the tool
	func callAsFunction() async throws(ContentError) -> CallTool.Result {
		do {
			var threads = try await dbAccessor.fetchAllThreads(limit: nil)
			
			// Apply date filtering if specified
			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
			
			if startDate != nil || endDate != nil {
				threads = threads.filter { thread in
					guard let threadDate = dateFormatter.date(from: thread.updatedAt) else {
						return false
					}
					
					if let startDate = startDate, threadDate < startDate {
						return false
					}
					
					if let endDate = endDate, threadDate > endDate {
						return false
					}
					
					return true
				}
			}
			
			// Apply limit after filtering
			if let limit = limit {
				threads = Array(threads.prefix(limit))
			}
			
			async let consumableThreads = threads.asyncConcurrentMap { await $0.consumable }
			
			var requestParts = ["zed-list-threads"]
			if let limit = limit {
				requestParts.append("limit: \(limit)")
			}
			if let startDate = startDate {
				requestParts.append("startDate: \(dateFormatter.string(from: startDate))")
			}
			if let endDate = endDate {
				requestParts.append("endDate: \(dateFormatter.string(from: endDate))")
			}
			
			let output = await StructuredContentOutput(
				inputRequest: requestParts.joined(separator: ", "),
				metaData: .init(resultCount: threads.count),
				content: consumableThreads)
			
			return output.toResult()
		} catch {
			throw .other(error)
		}
	}
}
