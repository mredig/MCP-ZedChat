import MCP
import Foundation

/// Protocol for tool implementations
protocol ToolImplementation: Sendable {
	/// The tool command identifier
	static var command: ToolCommand { get }
	
	/// The MCP Tool definition
	static var tool: Tool { get }
	
	/// Initialize with tool arguments, extracting and validating required parameters
	init(arguments: CallTool.Parameters, dbAccessor: ZedThreadsInterface) throws(ContentError)

	/// Execute the tool and return structured output
	func callAsFunction() async throws(ContentError) -> CallTool.Result
}
