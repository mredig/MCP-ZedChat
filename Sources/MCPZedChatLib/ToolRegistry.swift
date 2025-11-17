import Foundation

/// Central registry for all tool implementations
///
/// To add a new tool:
/// 1. Create a new file in `ToolImplementations/` directory
/// 2. Extend `ToolCommand` with your command constant
/// 3. Implement the `ToolImplementation` protocol
/// 4. Add your tool type to the `registeredTools` dictionary below
enum ToolRegistry {
	/// All registered tool implementations mapped by their command
	///
	/// Add your custom tool types here to make them available to the MCP server.
	/// The key is the tool's command, the value is the tool implementation type.
	static let registeredTools: [ToolCommand: any ToolImplementation.Type] = [
		.listThreads: ListThreadsTool.self,
		.getThread: GetThreadTool.self,
		.searchThreads: SearchThreadsTool.self,
		.searchThreadContent: SearchThreadContentTool.self,
	]
}
