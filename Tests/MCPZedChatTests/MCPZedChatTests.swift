import XCTest
import MCP
import Logging
@testable import MCPZedChat

final class MCPZedChatTests: XCTestCase {
    var logger: Logger!
    
    override func setUp() async throws {
        logger = Logger(label: "com.zedchat.tests")
        logger.logLevel = .debug
    }
    
    // MARK: - Tool Tests
    
    func testEchoTool() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        // Create a client and connect
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        // Test echo tool
        let (content, isError) = try await client.callTool(
            name: "echo",
            arguments: ["message": "Hello, World!"]
        )
        
        XCTAssertFalse(isError, "Echo tool should not return an error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let text) = content.first {
            XCTAssertEqual(text, "Echo: Hello, World!")
        } else {
            XCTFail("Expected text content")
        }
        
        await server.stop()
    }
    
    func testCalculateTool() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        // Test addition
        let (addContent, addError) = try await client.callTool(
            name: "calculate",
            arguments: [
                "operation": "add",
                "a": 10,
                "b": 5
            ]
        )
        
        XCTAssertFalse(addError, "Calculate tool should not return an error")
        if case .text(let text) = addContent.first {
            XCTAssertEqual(text, "15.0")
        } else {
            XCTFail("Expected text content")
        }
        
        // Test multiplication
        let (mulContent, mulError) = try await client.callTool(
            name: "calculate",
            arguments: [
                "operation": "multiply",
                "a": 6,
                "b": 7
            ]
        )
        
        XCTAssertFalse(mulError, "Calculate tool should not return an error")
        if case .text(let text) = mulContent.first {
            XCTAssertEqual(text, "42.0")
        } else {
            XCTFail("Expected text content")
        }
        
        // Test division by zero
        let (divContent, divError) = try await client.callTool(
            name: "calculate",
            arguments: [
                "operation": "divide",
                "a": 10,
                "b": 0
            ]
        )
        
        XCTAssertTrue(divError, "Division by zero should return an error")
        if case .text(let text) = divContent.first {
            XCTAssertTrue(text.contains("Division by zero"))
        } else {
            XCTFail("Expected text content")
        }
        
        await server.stop()
    }
    
    func testTimestampTool() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        let (content, isError) = try await client.callTool(
            name: "timestamp",
            arguments: [:]
        )
        
        XCTAssertFalse(isError, "Timestamp tool should not return an error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let text) = content.first {
            // Verify it's a valid ISO 8601 timestamp
            let formatter = ISO8601DateFormatter()
            XCTAssertNotNil(formatter.date(from: text), "Should be valid ISO 8601 timestamp")
        } else {
            XCTFail("Expected text content")
        }
        
        await server.stop()
    }
    
    // MARK: - Resource Tests
    
    func testListResources() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
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
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        // Test reading status resource
        let statusContents = try await client.readResource(uri: "zedchat://status")
        XCTAssertEqual(statusContents.count, 1, "Should have one content item")
        
        if case .text(let text, _, let mimeType) = statusContents.first {
            XCTAssertEqual(mimeType, "application/json")
            XCTAssertTrue(text.contains("status"), "Status should contain 'status' field")
            XCTAssertTrue(text.contains("version"), "Status should contain 'version' field")
        } else {
            XCTFail("Expected text content")
        }
        
        // Test reading welcome resource
        let welcomeContents = try await client.readResource(uri: "zedchat://welcome")
        XCTAssertEqual(welcomeContents.count, 1, "Should have one content item")
        
        if case .text(let text, _, let mimeType) = welcomeContents.first {
            XCTAssertEqual(mimeType, "text/plain")
            XCTAssertTrue(text.contains("Welcome"), "Welcome should contain greeting")
        } else {
            XCTFail("Expected text content")
        }
        
        await server.stop()
    }
    
    // MARK: - Prompt Tests
    
    func testListPrompts() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        let (prompts, _) = try await client.listPrompts()
        
        XCTAssertGreaterThan(prompts.count, 0, "Should have prompts available")
        
        let names = prompts.map { $0.name }
        XCTAssertTrue(names.contains("greeting"), "Should have greeting prompt")
        XCTAssertTrue(names.contains("code-review"), "Should have code-review prompt")
        XCTAssertTrue(names.contains("debug-session"), "Should have debug-session prompt")
        
        await server.stop()
    }
    
    func testGetGreetingPrompt() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        let (description, messages) = try await client.getPrompt(
            name: "greeting",
            arguments: ["name": "Alice"]
        )
        
        XCTAssertNotNil(description, "Should have a description")
        XCTAssertGreaterThan(messages.count, 0, "Should have messages")
        
        // Check that the name is included in the messages
        let messageTexts = messages.compactMap { message -> String? in
            if case .text(let text) = message.content {
                return text
            }
            return nil
        }
        
        let containsName = messageTexts.contains { $0.contains("Alice") }
        XCTAssertTrue(containsName, "Prompt should include the provided name")
        
        await server.stop()
    }
    
    func testGetCodeReviewPrompt() async throws {
        let server = createTestServer()
        await ServerHandlers.registerHandlers(on: server)
        
        let transport = InMemoryTransport()
        try await server.start(transport: transport)
        
        let client = Client(name: "TestClient", version: "1.0.0")
        try await client.connect(transport: transport)
        
        let (description, messages) = try await client.getPrompt(
            name: "code-review",
            arguments: [
                "language": "Swift",
                "focus": "memory safety"
            ]
        )
        
        XCTAssertNotNil(description, "Should have a description")
        XCTAssertGreaterThan(messages.count, 0, "Should have messages")
        
        // Check that language and focus are included
        let messageTexts = messages.compactMap { message -> String? in
            if case .text(let text) = message.content {
                return text
            }
            return nil
        }
        
        let containsLanguage = messageTexts.contains { $0.contains("Swift") }
        let containsFocus = messageTexts.contains { $0.contains("memory safety") }
        
        XCTAssertTrue(containsLanguage, "Prompt should include the language")
        XCTAssertTrue(containsFocus, "Prompt should include the focus area")
        
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