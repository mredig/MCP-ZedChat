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
		await registerPromptHandlers(on: server)
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
					name: "echo",
					description: "Echoes back the provided message",
					inputSchema: .object([
						"type": "object",
						"properties": .object([
							"message": .object([
								"type": "string",
								"description": "The message to echo back"
							])
						]),
						"required": .array([.string("message")])
					])
				),
				Tool(
					name: "calculate",
					description: "Performs basic arithmetic calculations",
					inputSchema: .object([
						"type": "object",
						"properties": .object([
							"operation": .object([
								"type": "string",
								"description": "The operation to perform",
								"enum": .array([.string("add"), .string("subtract"), .string("multiply"), .string("divide")])
							]),
							"a": .object([
								"type": "number",
								"description": "First number"
							]),
							"b": .object([
								"type": "number",
								"description": "Second number"
							])
						]),
						"required": .array([.string("operation"), .string("a"), .string("b")])
					])
				),
				Tool(
					name: "timestamp",
					description: "Returns the current timestamp in ISO 8601 format",
					inputSchema: .object([
						"type": "object",
						"properties": .object([:])
					])
				),
				Tool(
					name: "zed-list-threads",
					description: "List all Zed chat threads from the threads database",
					inputSchema: .object([
						"type": "object",
						"properties": .object([:])
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
							])
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
							])
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

			switch params.name {
			case "echo":
				guard let message = params.arguments?["message"]?.stringValue else {
					return .init(
						content: [.text("Error: Missing 'message' parameter")],
						isError: true
					)
				}
				return .init(
					content: [.text("Echo: \(message)")],
					isError: false
				)

			case "calculate":
				return handleCalculate(arguments: params.arguments)

			case "timestamp":
				let timestamp = ISO8601DateFormatter().string(from: Date())
				return .init(
					content: [.text(timestamp)],
					isError: false
				)

			case "zed-list-threads":
				return await handleZedListThreads()

			case "zed-get-thread":
				return await handleZedGetThread(arguments: params.arguments)

			case "zed-search-threads":
				return await handleZedSearchThreads(arguments: params.arguments)

			default:
				return .init(
					content: [.text("Unknown tool: \(params.name)")],
					isError: true
				)
			}
		}
	}

	private static func handleCalculate(arguments: [String: Value]?) -> CallTool.Result {
		guard let operation = arguments?["operation"]?.stringValue,
			  let aValue = arguments?["a"],
			  let bValue = arguments?["b"] else {
			return .init(
				content: [.text("Error: Missing required parameters (operation, a, b)")],
				isError: true
			)
		}

		guard let a = aValue.numberValue,
			  let b = bValue.numberValue else {
			return .init(
				content: [.text("Error: Parameters 'a' and 'b' must be numbers")],
				isError: true
			)
		}

		let result: Double
		switch operation {
		case "add":
			result = a + b
		case "subtract":
			result = a - b
		case "multiply":
			result = a * b
		case "divide":
			guard b != 0 else {
				return .init(
					content: [.text("Error: Division by zero")],
					isError: true
				)
			}
			result = a / b
		default:
			return .init(
				content: [.text("Error: Unknown operation '\(operation)'")],
				isError: true
			)
		}

		return .init(
			content: [.text("\(result)")],
			isError: false
		)
	}

	// MARK: - Zed Threads Tool Handlers

	private static func handleZedListThreads() async -> CallTool.Result {
		do {
			let threads = try await dbAccessor.fetchAllThreads()
			async let consumableThreads = threads.asyncConcurrentMap { await $0.consumable }

			let output = await StructuredContentOutput(
				metaData: .init(resultCount: threads.count),
				content: consumableThreads)

			let outputString = try encodeToJSONString(output)

			return .init(
				content: [.text(outputString)],
				isError: false
			)
		} catch {
			return .init(
				content: [.text("Error listing threads: \(error)")],
				isError: true
			)
		}
	}

	private static func handleZedGetThread(arguments: [String: Value]?) async -> CallTool.Result {
		guard let threadId = arguments?["id"]?.stringValue else {
			return .init(
				content: [.text("Error: Missing 'id' parameter")],
				isError: true
			)
		}

		do {
			guard let uuid = UUID(uuidString: threadId) else {
				return .init(content: [.text("Error: invalid thread id")], isError: true)
			}

			let thread = try await dbAccessor.fetchThread(id: uuid)

			let output = await StructuredContentOutput(
				metaData: .init(summary: "Thread Details"),
				content: thread.consumable)
			let outputString = try encodeToJSONString(output)

			return .init(
				content: [.text(outputString)],
				isError: false)
		} catch {
			return .init(
				content: [.text("Error fetching thread: \(error)")],
				isError: true)
		}
	}

	private static func handleZedSearchThreads(arguments: [String: Value]?) async -> CallTool.Result {
		guard let query = arguments?["query"]?.stringValue else {
			return .init(
				content: [.text("Error: Missing 'query' parameter")],
				isError: true
			)
		}

		do {
			let threadResults = try dbAccessor.searchThreadTitles(for: query)
			async let consumableThreadResults = threadResults.asyncConcurrentMap { await $0.consumable }

			let output = await StructuredContentOutput(
				metaData: .init(summary: "Thread Titles Search Results", resultCount: threadResults.count),
				content: consumableThreadResults)
			let outputString = try encodeToJSONString(output)

			return .init(
				content: [.text(outputString)],
				isError: false)
		} catch {
			return .init(
				content: [.text("Error searching threads: \(error)")],
				isError: true)
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

	// MARK: - Prompt Handlers

	private static func registerPromptHandlers(on server: Server) async {
		// List available prompts
		await server.withMethodHandler(ListPrompts.self) { _ in
			logger.debug("Listing prompts")

			let prompts = [
				Prompt(
					name: "greeting",
					description: "A friendly greeting prompt",
					arguments: [
						.init(name: "name", description: "Name of the person to greet", required: false)
					]
				),
				Prompt(
					name: "code-review",
					description: "Start a code review conversation",
					arguments: [
						.init(name: "language", description: "Programming language", required: true),
						.init(name: "focus", description: "What to focus on (e.g., security, performance)", required: false)
					]
				),
				Prompt(
					name: "debug-session",
					description: "Initialize a debugging conversation",
					arguments: [
						.init(name: "error", description: "Error message or description", required: true),
						.init(name: "context", description: "Additional context", required: false)
					]
				)
			]

			return .init(prompts: prompts, nextCursor: nil)
		}

		// Handle prompt retrieval
		await server.withMethodHandler(GetPrompt.self) { params in
			logger.debug("Getting prompt", metadata: ["name": "\(params.name)"])

			switch params.name {
			case "greeting":
				let name = params.arguments?["name"]?.stringValue ?? "there"
				let description = "A friendly greeting"
				let messages: [Prompt.Message] = [
					.assistant("Hello \(name)! How can I assist you today?"),
					.user("I'd like to learn more about this MCP server.")
				]
				return .init(description: description, messages: messages)

			case "code-review":
				guard let language = params.arguments?["language"]?.stringValue else {
					throw MCPError.invalidParams("Missing required argument: language")
				}

				let focus = params.arguments?["focus"]?.stringValue ?? "general code quality"
				let description = "Code review session for \(language)"
				let messages: [Prompt.Message] = [
					.user("You are an expert \(language) code reviewer. Focus on \(focus)."),
					.assistant("I'm ready to review your \(language) code with a focus on \(focus). Please share the code you'd like me to review.")
				]
				return .init(description: description, messages: messages)

			case "debug-session":
				guard let error = params.arguments?["error"]?.stringValue else {
					throw MCPError.invalidParams("Missing required argument: error")
				}

				let context = params.arguments?["context"]?.stringValue ?? "No additional context provided"
				let description = "Debugging session"
				let messages: [Prompt.Message] = [
					.user("You are a debugging assistant. Help identify and resolve the issue."),
					.user("I'm encountering this error: \(error)"),
					.user("Additional context: \(context)"),
					.assistant("Let me help you debug this issue. Can you provide more details about when this error occurs and what you've tried so far?")
				]
				return .init(description: description, messages: messages)

			default:
				throw MCPError.invalidParams("Unknown prompt: \(params.name)")
			}
		}
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
		let content: Content

		struct Metadata: Codable, Sendable {
			let summary: String?
			let resultCount: Int?

			init(summary: String? = nil, resultCount: Int? = nil) {
				self.summary = summary
				self.resultCount = resultCount
			}
		}
	}

	private static func encodeToJSONString<E: Encodable>(_ encodable: E) throws -> String {
		let data = try encoder.encode(encodable)
		return String(decoding: data, as: UTF8.self)
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
