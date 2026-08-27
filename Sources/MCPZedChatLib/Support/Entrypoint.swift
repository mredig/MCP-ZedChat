import MCP
import ServiceLifecycle
import Logging

public enum Entrypoint {
	public static func run() async throws {
		// Configure logging system
		LoggingSystem.bootstrap { label in
			var handler = StreamLogHandler.standardOutput(label: label)
			handler.logLevel = .info
			return handler
		}

		let logger = Logger(label: "com.zedchat.mcp-server")

		logger.info("Starting MCP ZedHist Server...")

		// Create the MCP server with capabilities
		let server = Server(
			version: "1.0.0",
			name: "MCP-ZedHist",
			capabilities: .init(
				resources: .init(subscribe: true, listChanged: true),
				tools: .init(listChanged: true)
			)
		)

		// Register all server handlers
		await ServerHandlers.registerHandlers(on: server)

		// Create stdio transport
		let transport = StdioTransport(logger: logger)

		// Create MCP service
		let mcpService = MCPService(server: server, transport: transport, logger: logger)

		// Create service group with signal handling for graceful shutdown
		let serviceGroup = ServiceGroup(
			services: [mcpService],
			gracefulShutdownSignals: [.sigterm, .sigint],
			logger: logger
		)

		logger.info("MCP ZedHist Server initialized and ready")

		// Run the service group - this blocks until shutdown signal
		try await serviceGroup.run()

		logger.info("MCP ZedHist Server shutdown complete")
	}
}
