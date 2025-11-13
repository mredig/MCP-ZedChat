# MCP-ZedChat

A Swift-based Model Context Protocol (MCP) server template built on the official [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk).

## Overview

This template provides a production-ready MCP server implementation with:

- **Tools**: Executable functions that can be called by MCP clients
- **Resources**: Data that can be accessed and subscribed to
- **Prompts**: Templated conversation starters with arguments
- **Graceful Shutdown**: Proper lifecycle management using Swift Service Lifecycle
- **Comprehensive Tests**: Example tests for all capabilities

## Requirements

- **Swift 6.0+** (Xcode 16+)
- **macOS 13.0+** (or compatible platform - see Platform Support below)

### Platform Support

| Platform | Minimum Version |
|----------|----------------|
| macOS | 13.0+ |
| iOS / Mac Catalyst | 16.0+ |
| watchOS | 9.0+ |
| tvOS | 16.0+ |
| visionOS | 1.0+ |
| Linux | Distributions with glibc or musl |

## Installation

### Clone and Build

```bash
# Clone this repository
git clone <your-repo-url>
cd MCP-ZedChat

# Build the project
swift build

# Run the server
swift run
```

### Swift Package Manager

Add this package as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "<your-repo-url>", from: "1.0.0")
]
```

## Usage

### Running the Server

The server uses stdio transport by default, making it compatible with MCP clients like Claude Desktop:

```bash
swift run mcp-zedchat
```

### Configuration with Claude Desktop

Add this server to your Claude Desktop configuration file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "zedchat": {
      "command": "/path/to/MCP-ZedChat/.build/debug/mcp-zedchat"
    }
  }
}
```

Or if you want to run it with `swift run`:

```json
{
  "mcpServers": {
    "zedchat": {
      "command": "swift",
      "args": ["run", "mcp-zedchat"],
      "cwd": "/path/to/MCP-ZedChat"
    }
  }
}
```

After updating the configuration, restart Claude Desktop.

## Available Capabilities

### Tools

The server includes several example tools:

#### `echo`
Echoes back a provided message.

**Arguments**:
- `message` (string, required): The message to echo

**Example**:
```json
{
  "message": "Hello, World!"
}
```

#### `calculate`
Performs basic arithmetic calculations.

**Arguments**:
- `operation` (string, required): One of "add", "subtract", "multiply", "divide"
- `a` (number, required): First number
- `b` (number, required): Second number

**Example**:
```json
{
  "operation": "add",
  "a": 10,
  "b": 5
}
```

#### `timestamp`
Returns the current timestamp in ISO 8601 format.

**Arguments**: None

### Resources

The server provides several informational resources:

#### `zedchat://status`
Current server status and statistics (JSON format)

#### `zedchat://welcome`
Welcome message and server information (plain text)

#### `zedchat://config`
Server configuration details (JSON format)

Resources support subscriptions, allowing clients to receive updates when resources change.

### Prompts

Pre-configured conversation starters:

#### `greeting`
A friendly greeting prompt.

**Arguments**:
- `name` (string, optional): Name of the person to greet

#### `code-review`
Start a code review conversation.

**Arguments**:
- `language` (string, required): Programming language
- `focus` (string, optional): What to focus on (e.g., security, performance)

#### `debug-session`
Initialize a debugging conversation.

**Arguments**:
- `error` (string, required): Error message or description
- `context` (string, optional): Additional context

## Development

### Project Structure

```
MCP-ZedChat/
├── Package.swift                  # Swift package manifest
├── Sources/
│   └── MCPZedChat/
│       ├── main.swift            # Entry point
│       ├── MCPService.swift      # Service lifecycle management
│       └── ServerHandlers.swift  # Tool/Resource/Prompt handlers
├── Tests/
│   └── MCPZedChatTests/
│       └── MCPZedChatTests.swift # Comprehensive tests
└── README.md
```

### Adding New Tools

To add a new tool, edit `Sources/MCPZedChat/ServerHandlers.swift`:

1. Add the tool definition in `registerToolHandlers`:

```swift
Tool(
    name: "my-new-tool",
    description: "Description of what it does",
    inputSchema: .object([
        "type": "object",
        "properties": .object([
            "param1": .object([
                "type": "string",
                "description": "Parameter description"
            ])
        ]),
        "required": .array([.string("param1")])
    ])
)
```

2. Add the handler in the `CallTool` switch statement:

```swift
case "my-new-tool":
    guard let param1 = params.arguments?["param1"]?.stringValue else {
        return .init(
            content: [.text("Error: Missing 'param1' parameter")],
            isError: true
        )
    }
    
    // Your implementation here
    let result = doSomething(with: param1)
    
    return .init(
        content: [.text(result)],
        isError: false
    )
```

### Adding New Resources

Edit the `registerResourceHandlers` function:

1. Add the resource to the list:

```swift
Resource(
    name: "My Resource",
    uri: "zedchat://my-resource",
    description: "Resource description",
    mimeType: "text/plain"
)
```

2. Add a case in the `ReadResource` handler:

```swift
case "zedchat://my-resource":
    let data = getResourceData() // Your implementation
    return .init(contents: [
        .text(data, uri: params.uri, mimeType: "text/plain")
    ])
```

### Adding New Prompts

Edit the `registerPromptHandlers` function similarly to tools and resources.

### Running Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run a specific test
swift test --filter MCPZedChatTests.testEchoTool
```

### Logging

The server uses Swift's `Logging` framework. Adjust log levels in `main.swift`:

```swift
var handler = StreamLogHandler.standardOutput(label: label)
handler.logLevel = .debug  // Change to .info, .warning, .error as needed
```

## Debugging

### Enable Debug Logging

Set the log level to `.debug` in `main.swift` to see detailed protocol messages:

```swift
handler.logLevel = .debug
```

### Test with MCP Inspector

Use the [MCP Inspector](https://github.com/modelcontextprotocol/inspector) to test your server:

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Run with your server
mcp-inspector swift run mcp-zedchat
```

### Common Issues

**Server doesn't start**:
- Check that all dependencies are resolved: `swift package resolve`
- Verify Swift version: `swift --version`

**Claude Desktop doesn't see the server**:
- Verify the path in `claude_desktop_config.json` is absolute
- Check that the executable exists and has execute permissions
- Restart Claude Desktop after configuration changes
- Check Claude Desktop logs (Help → View Logs)

**Tools return errors**:
- Enable debug logging to see full error messages
- Check that argument names match exactly (case-sensitive)
- Verify argument types (string, number, boolean, etc.)

## Architecture

### Service Lifecycle

The server uses [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle) for proper startup and shutdown:

- **SIGTERM** and **SIGINT** signals trigger graceful shutdown
- Server properly closes transport connections
- Configurable shutdown timeout prevents hanging processes

### Transport Layer

Currently uses **stdio transport** for communication:
- Reads from standard input
- Writes to standard output
- Compatible with Claude Desktop and other MCP clients

Future versions may support:
- HTTP/SSE transport for remote servers
- Custom transports for specialized use cases

### Concurrency

Built with Swift's modern concurrency model:
- All handlers are async
- Uses actors where appropriate for thread safety
- Leverages structured concurrency with ServiceLifecycle

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `swift test`
5. Submit a pull request

## Resources

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle)
- [Claude Desktop Configuration](https://docs.anthropic.com/claude/docs/mcp)

## License

MIT License - see LICENSE file for details

## Support

For issues or questions:
- Open an issue on GitHub
- Check the [MCP Swift SDK documentation](https://github.com/modelcontextprotocol/swift-sdk)
- Join the MCP community discussions

---

**Note**: This is a template. Customize the tools, resources, and prompts to fit your specific use case!