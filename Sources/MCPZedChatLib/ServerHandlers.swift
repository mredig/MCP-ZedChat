import MCP
import Logging
import Foundation

/// ServerHandlers contains all MCP request handlers for tools, resources, and prompts
enum ServerHandlers {
	private static let logger = Logger(label: "com.zedchat.mcp-handlers")

	/// Register all handlers on the given server
	static func registerHandlers(on server: Server) async {
		await registerToolHandlers(on: server)
		await registerResourceHandlers(on: server)
		await registerLifecycleHandlers(on: server)
	}

	static let dbAccessor = ZedThreadsInterface()
	private static let encoder = JSONEncoder().with {
		$0.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		$0.dateEncodingStrategy = .iso8601
	}

	// MARK: - Tool Handlers

	private static func registerToolHandlers(on server: Server) async {
		// List available tools
		await server.withMethodHandler(ListTools.self) { _ in
			logger.debug("Listing tools")

			let tools = [
				Tool(
					name: "zed-list-threads",
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
				),
				Tool(
					name: "zed-get-thread",
					description: "Get a specific Zed chat thread by ID",
					inputSchema: .object([
						"type": "object",
						"properties": .object([
							"id": .object([
								"type": "string",
								"description": "The thread ID"
							]),
							"rangeStart": .object([
								"type": "integer",
								"description": "The starting index (inclusive) of the range of messages to retrieve. Required if `rangeEnd` is specified."
							]),
							"rangeEnd": .object([
								"type": "integer",
								"description": "The ending index (non-inclusive) of the range of messages to retrieve. Required if `rangeStart` is specified."
							]),
						]),
						"required": .array([.string("id")])
					])
				),
				Tool(
					name: "zed-search-threads",
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
				),
				Tool(
					name: "zed-search-thread-content",
					description: "Search Zed chat threads by decoding their thread content and searching inside",
					inputSchema: .object([
						"type": "object",
						"properties": .object([
							"query": .object([
								"type": "string",
								"description": "Search query to match against thread summaries. There's no special syntax. Matches must be exact (apart from case sensitivity, specified in another argument)"
							]),
							"caseInsensitive": .object([
								"type": "boolean",
								"description": "Whether the query matching is case sensitive"
							]),
							"onlyFirstMatchPerThread": .object([
								"type": "boolean",
								"description": "When true, message filtering will stop on a thread once a message is found with a match. When false, all matching messages on the thread will be returned. It is more efficient to set to true, when exhaustion isn't necessary."
							]),


						]),
						"required": .array([.string("query")])
					])
				)
			]

			return .init(tools: tools, nextCursor: nil)
		}

		// Handle tool calls
		await server.withMethodHandler(CallTool.self) { params in
			logger.debug("Calling tool", metadata: ["tool": "\(params.name)"])

			do throws(ContentError) {
				switch params.name {
				case "zed-list-threads":
					let limit = params.integers.limit
					return try await handleZedListThreads(limit: limit)

				case "zed-get-thread":
					guard
						let id = params.strings.id
					else { throw .contentError(message: "Missing thread id") }

					let range: Range<Int>? = {
						guard
							let rangeStart = params.integers.rangeStart,
							let rangeEnd = params.integers.rangeEnd,
							rangeStart <= rangeEnd
						else { return nil }

						return rangeStart..<rangeEnd
					}()

					return try await handleZedGetThread(threadID: id, messageRange: range)

				case "zed-search-threads":
					let limit = params.integers.limit
					return try await handleZedSearchThreads(arguments: params.arguments, limit: limit)

				case "zed-search-thread-content":
					guard let query = params.strings.query else { throw .contentError(message: "Missing query argument") }
					return try await handleZedSearchThreadsContent(
						query: query,
						limit: params.integers.limit,
						caseInsensitive: params.bools.caseInsensitive ?? true,
						onlyFirstMatchPerThread: params.bools.onlyFirstMatchPerThread ?? false)
				default:
					throw .contentError(message: "Unknown tool")
				}
			} catch {
				switch error {
				case .contentError(message: let message):
					let errorMessage = "Error performing \(params.name): \(message ?? "Content Error")"
					return .init(content: [.text(errorMessage)], isError: true)
				case .other(let error):
					return .init(content: [.text("Error performing \(params.name): \(error)")], isError: true)
				}
			}
		}
	}

	// MARK: - Zed Threads Tool Handlers

	private static func handleZedListThreads(limit: Int?) async throws(ContentError) -> CallTool.Result {
		do {
			let threads = try await dbAccessor.fetchAllThreads(limit: limit)
			async let consumableThreads = threads.asyncConcurrentMap { await $0.consumable }

			let output = await StructuredContentOutput(
				metaData: .init(resultCount: threads.count),
				content: consumableThreads)

			return output.toResult()
		} catch {
			throw .other(error)
		}
	}

	private static func handleZedGetThread(threadID: String, messageRange: Range<Int>?) async throws(ContentError) -> CallTool.Result {
		do {
			let thread = try await dbAccessor.fetchThread(id: threadID)

			async let response = thread.consumableWithContent(withMessageRange: messageRange)

			let output = await StructuredContentOutput(
				metaData: .init(summary: "Thread Details"),
				content: [response].compactMap(\.self))

			return output.toResult()
		} catch {
			throw .other(error)
		}
	}

	private static func handleZedSearchThreads(arguments: [String: Value]?, limit: Int?) async throws(ContentError) -> CallTool.Result {
		guard let query = arguments?["query"]?.stringValue else {
			return .init(
				content: [.text("Error: Missing 'query' parameter")],
				isError: true
			)
		}

		do {
			let threadResults = try dbAccessor.searchThreadTitles(for: query, limit: limit)
			async let consumableThreadResults = threadResults.asyncConcurrentMap { await $0.consumable }

			let output = await StructuredContentOutput(
				metaData: .init(summary: "Thread Titles Search Results", resultCount: threadResults.count),
				content: consumableThreadResults)

			return output.toResult()
		} catch {
			throw .other(error)
		}
	}

	private static func handleZedSearchThreadsContent(query: String, limit: Int?, caseInsensitive: Bool, onlyFirstMatchPerThread: Bool) async throws(ContentError) -> CallTool.Result {
		do {
			let threadResults = try await dbAccessor.searchThreadContent(
				for: query,
				caseInsensitive: caseInsensitive,
				limit: limit,
				onlyFirstMatchPerThread: onlyFirstMatchPerThread)

			let output = StructuredContentOutput(
				metaData: .init(summary: "Thread Content Search Results", resultCount: threadResults.count),
				content: threadResults)

			return output.toResult()
		} catch {
			throw .other(error)
		}
	}

	// MARK: - Resource Handlers

	private static func registerResourceHandlers(on server: Server) async {
		// List available resources
		await server.withMethodHandler(ListResources.self) { _ in
			logger.debug("Listing resources")

			let resources = [
				Resource(
					name: "Server Status",
					uri: "zedchat://status",
					description: "Current server status and statistics",
					mimeType: "application/json"
				),
				Resource(
					name: "Welcome Message",
					uri: "zedchat://welcome",
					description: "Welcome message and server information",
					mimeType: "text/plain"
				),
				Resource(
					name: "Server Configuration",
					uri: "zedchat://config",
					description: "Server configuration details",
					mimeType: "application/json"
				)
			]

			return .init(resources: resources, nextCursor: nil)
		}

		// Handle resource reads
		await server.withMethodHandler(ReadResource.self) { params in
			logger.debug("Reading resource", metadata: ["uri": "\(params.uri)"])

			switch params.uri {
			case "zedchat://status":
				let statusJson = """
				{
					"status": "healthy",
					"uptime": "running",
					"version": "1.0.0",
					"timestamp": "\(ISO8601DateFormatter().string(from: Date()))"
				}
				"""
				return .init(contents: [
					.text(statusJson, uri: params.uri, mimeType: "application/json")
				])

			case "zedchat://welcome":
				let welcome = """
				Welcome to MCP ZedChat Server!
				
				This is a Model Context Protocol server built with Swift.
				It provides tools, resources, and prompts for AI interaction.
				
				Version: 1.0.0
				"""
				return .init(contents: [
					.text(welcome, uri: params.uri, mimeType: "text/plain")
				])

			case "zedchat://config":
				let configJson = """
				{
					"name": "MCP-ZedChat",
					"version": "1.0.0",
					"capabilities": {
						"tools": true,
						"resources": true,
						"prompts": true,
						"sampling": false
					},
					"transport": "stdio"
				}
				"""
				return .init(contents: [
					.text(configJson, uri: params.uri, mimeType: "application/json")
				])

			default:
				throw MCPError.invalidParams("Unknown resource URI: \(params.uri)")
			}
		}

		// Handle resource subscriptions
		await server.withMethodHandler(ResourceSubscribe.self) { params in
			logger.info("Client subscribed to resource", metadata: ["uri": "\(params.uri)"])

			// In a real implementation, you would:
			// 1. Store the subscription for this client
			// 2. Send notifications when the resource changes
			// 3. Use server.sendNotification(...) to push updates

			return .init()
		}

		// Note: Resource unsubscribe handler not included as UnsubscribeResource
		// may not be available in the current MCP Swift SDK version
	}

	// MARK: - Lifecycle Handlers

	private static func registerLifecycleHandlers(on server: Server) async {
		// Handle shutdown request
		await server.withMethodHandler(Shutdown.self) { [weak server] _ in
			logger.info("Shutdown request received - preparing to exit")
			Task {
				guard let server else {
					throw NSError(domain: "foo", code: 12)
				}
				try await Task.sleep(for: .milliseconds(100))
				logger.info("Calling server.stop()")
				await server.stop()
				logger.info("Server stopped, calling _exit")
				_exit(0)
			}
			return .init()
		}
	}

	// MARK: - Output Structure

	private struct StructuredContentOutput<Content: Codable & Sendable>: Codable, Sendable {
		let metaData: Metadata?
		let content: [Content]

		struct Metadata: Codable, Sendable {
			let summary: String?
			let resultCount: Int?

			init(summary: String? = nil, resultCount: Int? = nil) {
				self.summary = summary
				self.resultCount = resultCount
			}
		}

		func toResult() -> CallTool.Result {
			var accumulator: [Tool.Content] = []

			if let metaData {
				let jsonString = try? Self.encodeToJSONString(metaData)
				jsonString.map { accumulator.append(.text($0)) }
			}

			for item in content {
				let jsonString = try? Self.encodeToJSONString(item)
				jsonString.map { accumulator.append(.text($0)) }
			}

			return .init(content: accumulator, isError: false)
		}

		private static func encodeToJSONString<E: Encodable>(_ encodable: E) throws -> String {
			let data = try encoder.encode(encodable)
			return String(decoding: data, as: UTF8.self)
		}
	}

	enum ContentError: Error {
		case contentError(message: String?)
		case other(Error)
	}
}

// MARK: - Value Extensions

extension Value {
	var numberValue: Double? {
		// Value in MCP SDK is ExpressibleByIntegerLiteral and ExpressibleByFloatLiteral
		// Try different approaches to extract numeric value

		// First, check if it's directly convertible via mirror inspection
		let mirror = Mirror(reflecting: self)

		// Check for integer value
		if let intVal = mirror.children.first(where: { $0.label == "integer" || $0.label == "int" })?.value as? Int {
			return Double(intVal)
		}

		// Check for double/float value
		if let doubleVal = mirror.children.first(where: { $0.label == "number" || $0.label == "double" })?.value as? Double {
			return doubleVal
		}

		// Try the accessor methods if they exist
		if let num = self.doubleValue {
			return num
		}

		// Try string parsing as last resort
		if let str = self.stringValue, let num = Double(str) {
			return num
		}

		return nil
	}
}
