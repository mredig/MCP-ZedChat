# MCP-ZedChat

A Swift MCP (Model Context Protocol) server for searching and accessing Zed chat history **from within Zed itself**.

## TLDR - Quick Start

**Install via Homebrew:**
```bash
brew tap mredig/pizza-mcp-tools
brew install mcp-zedchat
```

**Or build from source:**
```bash
git clone https://github.com/mredig/MCP-ZedChat.git
cd MCP-ZedChat
swift build -c release
```

**Add to Zed settings** (`~/.config/zed/settings.json`):
```json
{
  "context_servers": {
    "zedchat": {
      "command": "mcp-zedchat"
    }
  }
}
```

## What It Does

Search your Zed chat history without leaving Zed. The real power is **automating information retrieval across conversations**:

**Move context between conversations:**
- Start a new chat but need details from an old discussion? The AI can search your history, gather relevant information, and bring it into the current context.
- "Find our conversation about the caching strategy we designed yesterday in a previous context, then help me implement it in this new project"

**Synthesize information from multiple threads:**
- "Search all conversations about performance optimization from the last month and summarize the patterns we've used"
- "What database schemas have we discussed? Compare them and recommend one for this new feature"

**Build on previous work without repetition:**
- "Look up the error handling approach from that SwiftUI project and apply it here"
- "Find where we debugged the async/await issue and check if this current error is related"

The AI automatically searches your history, retrieves relevant snippets, and applies that knowledge - you don't manually hunt through old chats.



## Available Tools

- **`zed-list-threads`** - List threads with optional date filtering and limits
- **`zed-get-message`** - Retrieve specific messages with character-level pagination
- **`zed-search-threads`** - Search thread titles/summaries  
- **`zed-search-thread-content`** - Search within messages, returns limited context snippets

All tools use smart caching and token-efficient designs (snippets instead of full content, pagination for large messages).

## Usage Examples

Ask natural language questions in Zed's assistant - it automatically uses these tools:

**"Find our previous discussion about authentication patterns and apply that approach to this login feature"**
- Searches history, retrieves relevant context, applies it to current work

**"Search all my conversations about API design from the last 2 months and summarize the best practices we identified"**  
- Aggregates information across multiple threads, synthesizes patterns

**"I'm working on error handling - what approaches have we used before?"**
- Searches for relevant discussions, brings solutions into current context

**"Look up that SwiftUI animation technique from the dashboard project"**
- Finds specific implementation details from old conversations

The assistant handles tool selection, searches, retrieval, and synthesis automatically.

## Technical Usage (for MCP clients)

If you're using this with other MCP clients (like Claude Desktop), add to your config:

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "zedchat": {
      "command": "mcp-zedchat"
    }
  }
}
```

**Other MCP Clients:** Point to the `mcp-zedchat` binary and use the tools via their JSON-RPC interface.

## For Developers

Want to add your own tools? The codebase uses a clean registry pattern:
1. Create tool in `Sources/MCPZedChatLib/ToolImplementations/`
2. Implement `ToolImplementation` protocol  
3. Register in `ToolRegistry.swift`

See existing tools for examples. Each follows the same pattern: define schema, extract parameters, implement logic.

## Requirements

- Swift 6.0+
- macOS 13.0+  
- Zed editor (provides the chat history database at `~/Library/Application Support/Zed/threads/threads.db`)

## Resources

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [JSON Schema Reference](https://json-schema.org/understanding-json-schema/reference)
- [Zed Editor](https://zed.dev/)

## License

MIT License
