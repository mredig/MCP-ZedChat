import XCTest
import MCP
import Logging
@testable import MCPZedChatLib

final class MCPZedChatTests: XCTestCase {
    var logger: Logger!
    
    override func setUp() async throws {
        logger = Logger(label: "com.zedchat.tests")
        logger.logLevel = .debug
    }
    
    // MARK: - Resource Tests
    
    func testListResources() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let (serverTransport, clientTransport) = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: serverTransport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: clientTransport)
        
        let (resources, _) = try await client.listResources()
        
        XCTAssertGreaterThan(resources.count, 0, "Should have resources available")
        
        let uris = resources.map { $0.uri }
        XCTAssertTrue(uris.contains("zedchat://status"), "Should have status resource")
        XCTAssertTrue(uris.contains("zedchat://welcome"), "Should have welcome resource")
        XCTAssertTrue(uris.contains("zedchat://config"), "Should have config resource")
        
        await server.stop()
    }
    
    func testReadResource() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)

        let (serverTransport, clientTransport) = await InMemoryTransport.createConnectedPair()
        try await server.start(transport: serverTransport)

        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: clientTransport)
        
        // Test reading status resource
        let statusContents = try await client.readResource(uri: "zedchat://status")
        XCTAssertEqual(statusContents.count, 1, "Should have one content item")

		if let firstStatusContent = statusContents.first, let text = firstStatusContent.text {
			let mimeType = firstStatusContent.mimeType

			XCTAssertEqual(mimeType, "application/json")
            XCTAssertTrue(text.contains("status"), "Status should contain 'status' field")
            XCTAssertTrue(text.contains("version"), "Status should contain 'version' field")
        } else {
            XCTFail("Expected text content")
        }
        
        // Test reading welcome resource
        let welcomeContents = try await client.readResource(uri: "zedchat://welcome")
        XCTAssertEqual(welcomeContents.count, 1, "Should have one content item")

		if let firstWelcome = welcomeContents.first, let text = firstWelcome.text {
			let mimeType = firstWelcome.mimeType
			XCTAssertEqual(mimeType, "text/plain")
			XCTAssertTrue(text.contains("Welcome"), "Welcome should contain greeting")
		} else {
            XCTFail("Expected text content")
        }
        
        await server.stop()
    }
    
    // MARK: - Helper Methods
    
    private func createTestServer() -> Server {
        return Server(
            name: "TestServer",
            version: "1.0.0",
            capabilities: .init(
                prompts: .init(listChanged: true),
                resources: .init(subscribe: true, listChanged: true),
                tools: .init(listChanged: true)
            )
        )
    }
}
