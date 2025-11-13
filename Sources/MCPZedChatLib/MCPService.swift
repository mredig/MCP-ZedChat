import MCP
import ServiceLifecycle
import Logging

/// MCPService manages the lifecycle of an MCP server
/// Integrates with Swift Service Lifecycle for graceful startup and shutdown
struct MCPService: Service {
    let server: Server
    let transport: Transport
    let logger: Logger
    
    init(server: Server, transport: Transport, logger: Logger? = nil) {
        self.server = server
        self.transport = transport
        self.logger = logger ?? Logger(label: "com.zedchat.mcp-service")
    }
    
    func run() async throws {
        logger.info("Starting MCP server...")
        
        // Start the server with optional initialize hook
        try await server.start(transport: transport) { clientInfo, clientCapabilities in
            logger.info("Client connected", metadata: [
                "name": "\(clientInfo.name)",
                "version": "\(clientInfo.version)"
            ])
            
            // Log client capabilities
            if clientCapabilities.sampling != nil {
                logger.debug("Client supports sampling")
            }
            if clientCapabilities.roots != nil {
                logger.debug("Client supports roots")
            }
            
            // You can add custom validation here
            // For example, block specific clients:
            // guard clientInfo.name != "BlockedClient" else {
            //     throw MCPError.invalidRequest("This client is not allowed")
            // }
        }
        
        logger.info("MCP server started successfully")
        
        // Keep running until external cancellation
        // The service will be cancelled when a shutdown signal is received
        try await Task.sleep(for: .seconds(60 * 60 * 24 * 365 * 100))  // Effectively forever
    }
    
    func shutdown() async throws {
        logger.info("Shutting down MCP server...")
        await server.stop()
        logger.info("MCP server stopped")
    }
}