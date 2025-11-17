import Foundation

/// Tool command identifier that can be extended in individual tool implementation files
struct ToolCommand: RawRepresentable, Hashable, Sendable {
	let rawValue: String
	
	init(rawValue: String) {
		self.rawValue = rawValue
	}
}