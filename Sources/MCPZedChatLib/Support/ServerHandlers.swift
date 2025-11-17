import MCP
import Logging
import Foundation

/// ServerHandlers contains all MCP request handlers for tools, resources, and prompts
enum ServerHandlers {
	private static let logger = Logger(label: "com.zedchat.mcp-handlers")

	/// Registered tool implementations from the central registry
	private static let toolImplementations = ToolRegistry.registeredTools

	/// Register all handlers on the given server
	static func registerHandlers(on server: Server) async {
		await registerToolHandlers(on: server)
		await registerResourceHandlers(on: server)
		await registerLifecycleHandlers(on: server)
	}

	// MARK: - Tool Handlers

	private static func registerToolHandlers(on server: Server) async {
		// List available tools
		await server.withMethodHandler(ListTools.self) { _ in
			logger.debug("Listing tools")

			let tools = toolImplementations.values.map { $0.tool }

			return .init(tools: tools, nextCursor: nil)
		}

		let dbAccessor = ZedThreadsInterface()

		// Handle tool calls
		await server.withMethodHandler(CallTool.self) { params in
			logger.debug("Calling tool", metadata: ["tool": "\(params.name)"])

			do throws(ContentError) {
				// Find the matching tool implementation via dictionary lookup (O(1))
				let command = ToolCommand(rawValue: params.name)
				guard let toolType = toolImplementations[command] else {
					throw .contentError(message: "Unknown tool '\(params.name)'")
				}

				// Create instance and execute
				let toolInstance = try toolType.init(arguments: params, dbAccessor: dbAccessor)
				return try await toolInstance()
			} catch {
				let errorMessage: String
				switch error {
				case .missingArgument(let arg):
					errorMessage = "Missing required argument: '\(arg)'"
				case .mismatchedType(let arg, let expected):
					errorMessage = "Argument '\(arg)' has incorrect type (expected: \(expected))"
				case .initializationFailed(let message):
					errorMessage = "Initialization failed: \(message)"
				case .contentError(message: let message):
					errorMessage = "Error performing \(params.name): \(message ?? "Content Error")"
				case .other(let error):
					errorMessage = "Error performing \(params.name): \(error)"
				}
				return .init(content: [.text(errorMessage)], isError: true)
			}
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
						"prompts": false,
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
	}

	// MARK: - Lifecycle Handlers

	private static func registerLifecycleHandlers(on server: Server) async {
		// Handle shutdown request
		await server.withMethodHandler(Shutdown.self) { [weak server] _ in
			logger.info("Shutdown request received - preparing to exit")
			Task {
				guard let server else {
					throw NSError(domain: "com.zedchat.mcp-server", code: 1)
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
}
