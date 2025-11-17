# MCP-ZedChat

A Swift MCP (Model Context Protocol) server for searching and accessing Zed chat history.

## TLDR - Quick Start

```bash
# Clone and build
git clone <your-repo-url>
cd MCP-ZedChat
swift build

# Add to Claude Desktop config at:
# ~/Library/Application Support/Claude/claude_desktop_config.json
{
  "mcpServers": {
    "zedchat": {
      "command": "/path/to/MCP-ZedChat/.build/debug/mcp-zedchat"
    }
  }
}

# Restart Claude Desktop - you're done!
```

## What It Does

Provides access to your Zed editor's chat history through MCP tools:
- Search chat threads by title
- Search within chat content
- Retrieve full thread details with filtering
- List all threads

Zed stores chat history in a SQLite database with compressed (zstd) content. This MCP server makes that data accessible to Claude and other MCP clients.

## Adding Your Own Tools

1. **Create a new file** in `Sources/MCPZedChatLib/ToolImplementations/`
2. **Extend `ToolCommand`** with your command name
3. **Implement `ToolImplementation` protocol**
4. **Add to registry** in `ToolRegistry.swift`

### Example: Adding a Simple Tool

```swift
// EchoTool.swift
import MCP
import Foundation

extension ToolCommand {
    static let echo = ToolCommand(rawValue: "echo")
}

struct EchoTool: ToolImplementation {
    static let command: ToolCommand = .echo
    
    static let tool = Tool(
        name: command.rawValue,
        description: "Echoes a message back",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "message": .object([
                    "type": "string",
                    "description": "The message to echo"
                ])
            ]),
            "required": .array([.string("message")])
        ])
    )
    
    let message: String
    private let dbAccessor: ZedThreadsInterface
    
    init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError) {
        self.dbAccessor = dbAccessor
        
        guard let message = arguments.strings.message else {
            throw .missingArgument("message")
        }
        self.message = message
    }
    
    func callAsFunction() async throws(ContentError) -> CallTool.Result {
        let output = StructuredContentOutput(
            inputRequest: "echo: \(message)",
            metaData: nil,
            content: [["echo": message]])
        
        return output.toResult()
    }
}
```

Then add to `ToolRegistry.swift`:
```swift
static let registeredTools: [ToolCommand: any ToolImplementation.Type] = [
    .listThreads: ListThreadsTool.self,
    .getThread: GetThreadTool.self,
    .searchThreads: SearchThreadsTool.self,
    .searchThreadContent: SearchThreadContentTool.self,
    .echo: EchoTool.self,  // ← Add your tool here
]
```

That's it! Rebuild and your tool is available.

## Project Structure

```
MCP-ZedChat/
├── Sources/MCPZedChatLib/
│   ├── ToolRegistry.swift              ← Register your tools here
│   ├── ToolCommands.swift               ← Tool command constants
│   ├── DB.swift                         ← Database schema (SQLite/Lighter)
│   ├── ZedThreadsInterface.swift        ← Database access layer
│   ├── ToolImplementations/             ← Put your tools here
│   │   ├── ToolImplementation.swift     ← Protocol definition
│   │   ├── ListThreadsTool.swift
│   │   ├── GetThreadTool.swift
│   │   ├── SearchThreadsTool.swift
│   │   ├── SearchThreadContentTool.swift
│   │   └── SharedModels/                ← Shared data models
│   │       ├── ZedThreadModels.swift
│   │       ├── ThreadFilter.swift
│   │       └── OldZedThreadModels.swift
│   └── Support/                         ← Implementation details (don't need to modify)
│       ├── ServerHandlers.swift
│       ├── ToolSupport.swift
│       └── ...
```

## Tool Implementation Pattern

Every tool follows the same pattern:

1. **Extend `ToolCommand`** - Define your command identifier
2. **Define `static let tool`** - MCP Tool definition with JSON Schema
3. **Extract parameters in `init`** - Validate and convert to typed properties
4. **Implement `callAsFunction`** - Your tool's business logic

### Parameter Extraction

Use the `ParamLookup` helpers to extract typed parameters:

```swift
arguments.strings.myStringParam    // String?
arguments.integers.myIntParam      // Int?
arguments.bools.myBoolParam        // Bool?
```

### Error Handling

Throw `ContentError` for all tool errors:

```swift
throw .missingArgument("paramName")
throw .mismatchedType(argument: "paramName", expected: "string")
throw .initializationFailed("custom message")
throw .contentError(message: "custom error")
throw .other(someError)
```

## Requirements

- Swift 6.0+
- macOS 13.0+
- Zed editor (for chat history database)

## Testing

```bash
swift test
```

## Available Tools

### `zed-list-threads`
List all Zed chat threads from the database with optional date filtering.

**Parameters:**
- `limit` (optional, integer) - Limit result count
- `startDate` (optional, string) - Filter threads updated after this date (ISO 8601 format, e.g. '2024-01-01T00:00:00Z')
- `endDate` (optional, string) - Filter threads updated before this date (ISO 8601 format, e.g. '2024-12-31T23:59:59Z')

**Returns:** Array of thread summaries with metadata.

**Note:** Date filtering uses the thread's `updatedAt` timestamp, which reflects the last modification time of the entire conversation.

### `zed-get-message`
Get a specific message from a thread with character-level pagination.

**Parameters:**
- `threadID` (required, string) - The thread ID
- `messageIndex` (required, integer) - The index of the message within the thread (0-based)
- `offset` (optional, integer) - Starting character position within the message (default: 0)
- `limit` (optional, integer) - Maximum number of characters to return (default: 1000)

**Returns:** Message content with pagination info. Includes:
- Message role (user/assistant)
- Paginated content
- Total message length
- Whether more content is available (`hasMore`, `nextOffset`)

**Use case:** After finding a message via search, use this tool to retrieve its full content in manageable chunks.

### `zed-search-threads`
Search thread titles/summaries.

**Parameters:**
- `query` (required, string) - Search query for thread summaries
- `limit` (optional, integer) - Limit result count

**Returns:** Array of matching threads.

### `zed-search-thread-content`
Search within thread message content with limited context to reduce token usage.

**Parameters:**
- `query` (required, string) - Search query (exact match, case-insensitive by default)
- `page` (optional, integer) - Page number for results (default: 0, 10 results per page)
- `caseInsensitive` (optional, boolean) - Whether search is case-insensitive (default: true)
- `onlyFirstMatchPerThread` (optional, boolean) - Stop after first match per thread (default: false)

**Returns:** Array of matches with limited context (~100 characters before and after the match). Each result includes:
- `threadID` and `threadSummary`
- `messageIndex` - Use with `zed-get-message` to retrieve full message
- `matchPosition` - Character position of match in message
- `contextBefore`, `matchText`, `contextAfter` - Limited surrounding text
- `messageRole` - Message sender (user/assistant)

**Use case:** Search broadly for content, then use `zed-get-message` with the returned `messageIndex` to see full context if needed.

### Resources
- `zedchat://status` - Server status (JSON)
- `zedchat://welcome` - Welcome message (text)
- `zedchat://config` - Server configuration (JSON)

## Usage Examples

### List all threads
```json
{
  "tool": "zed-list-threads",
  "arguments": {}
}
```

### List threads from the last week
```json
{
  "tool": "zed-list-threads",
  "arguments": {
    "startDate": "2024-11-10T00:00:00Z",
    "limit": 20
  }
}
```

### Get a specific message from a thread
```json
{
  "tool": "zed-get-message",
  "arguments": {
    "threadID": "thread-id-here",
    "messageIndex": 5
  }
}
```

### Get message with character pagination
```json
{
  "tool": "zed-get-message",
  "arguments": {
    "threadID": "thread-id-here",
    "messageIndex": 5,
    "offset": 1000,
    "limit": 1000
  }
}
```

### Search thread titles
```json
{
  "tool": "zed-search-threads",
  "arguments": {
    "query": "refactoring"
  }
}
```

### Search within thread content (returns limited context)
```json
{
  "tool": "zed-search-thread-content",
  "arguments": {
    "query": "ToolImplementation",
    "caseInsensitive": true
  }
}
```

**Example result:**
```json
{
  "threadID": "abc123",
  "messageIndex": 5,
  "matchPosition": 1234,
  "contextBefore": "...text before ",
  "matchText": "ToolImplementation",
  "contextAfter": " text after...",
  "messageRole": "user"
}
```

Then retrieve full message if needed:
```json
{
  "tool": "zed-get-message",
  "arguments": {
    "threadID": "abc123",
    "messageIndex": 5
  }
}
```

## Database Location

Zed stores chat threads at:
```
~/Library/Application Support/Zed/threads/threads.db
```

The database contains compressed (zstd) JSON data for each thread. This server handles decompression and parsing automatically.

## Resources

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference)
- [Zed Editor](https://zed.dev/)

## License

MIT License