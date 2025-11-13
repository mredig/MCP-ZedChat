import MCP

/// Shutdown request - client requests server to prepare for shutdown
/// Server should stop accepting new requests but complete pending ones
/// - SeeAlso: JSON-RPC 2.0 specification
public enum Shutdown: Method {
	public static let name: String = "shutdown"

	public typealias Parameters = EmptyParameters

	public struct Result: Hashable, Codable, Sendable {
		public init() {}
	}
}

/// Empty parameters for methods that don't require parameters
public struct EmptyParameters: Hashable, Codable, Sendable {
	public init() {}
}
