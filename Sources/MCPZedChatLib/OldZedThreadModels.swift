import Foundation

// MARK: - Zed Thread Models for 0.2.0 Format

enum Legacy {
	/// Message structure for Zed 0.2.0 format
	/// This uses a flat structure with a `role` field to distinguish user vs agent messages
	struct ZedThreadMessage_0_2_0: Codable, Sendable {
		let id: Int?
		let role: Role
		let segments: [Segment]
		let toolUses: [ToolUse]
		let toolResults: [ToolResult]
		let context: String?
		let isHidden: Bool?

		enum Role: String, Codable, Sendable {
			case user
			case assistant
		}

		enum CodingKeys: String, CodingKey {
			case id
			case role
			case segments
			case toolUses = "tool_uses"
			case toolResults = "tool_results"
			case context
			case isHidden = "is_hidden"
		}
	}
}

// MARK: - Segments (Content in 0.2.0)

extension Legacy.ZedThreadMessage_0_2_0 {
	struct Segment: Codable, Sendable {
		let type: SegmentType
		let text: String?
		
		enum SegmentType: String, Codable, Sendable {
			case text
			case code
			case image
			case unknown
			
			init(from decoder: Decoder) throws {
				let container = try decoder.singleValueContainer()
				let rawValue = try container.decode(String.self)
				self = SegmentType(rawValue: rawValue) ?? .unknown
			}
		}
		
		enum CodingKeys: String, CodingKey {
			case type
			case text
		}
	}
}

// MARK: - Tool Uses (0.2.0)

extension Legacy.ZedThreadMessage_0_2_0 {
	struct ToolUse: Codable, Sendable {
		let id: String
		let name: String
		let input: [String: AnyCodable]
		
		enum CodingKeys: String, CodingKey {
			case id
			case name
			case input
		}
	}
}

// MARK: - Tool Results (0.2.0)

extension Legacy.ZedThreadMessage_0_2_0 {
	struct ToolResult: Codable, Sendable {
		let toolUseId: String
		let isError: Bool
		let content: Content
		let output: [String: AnyCodable]?
		
		enum CodingKeys: String, CodingKey {
			case toolUseId = "tool_use_id"
			case isError = "is_error"
			case content
			case output
		}
		
		struct Content: Codable, Sendable {
			let text: String?
			
			enum CodingKeys: String, CodingKey {
				case text = "Text"
			}
			
			init(from decoder: Decoder) throws {
				let container = try decoder.singleValueContainer()
				
				// Try to decode as a dictionary with "Text" key
				if let dict = try? container.decode([String: String].self),
				   let textValue = dict["Text"] {
					self.text = textValue
				} else {
					// Fallback to direct string
					self.text = try? container.decode(String.self)
				}
			}
			
			func encode(to encoder: Encoder) throws {
				var container = encoder.singleValueContainer()
				if let text = text {
					try container.encode(["Text": text])
				} else {
					try container.encodeNil()
				}
			}
		}
	}
}

// MARK: - Conversion to Modern Format

extension Legacy.ZedThreadMessage_0_2_0 {
	/// Convert 0.2.0 message format to 0.3.0 format
	func toVersion0_3_0() -> ZedThread.Message {
		var content: [ZedThread.Message.Content] = []
		
		// Convert segments to content
		for segment in segments {
			if let text = segment.text {
				content.append(.text(text))
			}
		}
		
		// Add tool uses as content
		for toolUse in toolUses {
			let modernToolUse = ZedThread.Message.Content.ToolUse(
				id: toolUse.id,
				name: toolUse.name,
				rawInput: nil,
				input: toolUse.input
			)
			content.append(.toolUse(modernToolUse))
		}
		
		// Create appropriate message type based on role
		switch role {
		case .user:
			return .user(ZedThread.Message.UserMessage(
				id: UUID().uuidString,
				content: content
			))
		case .assistant:
			return .agent(ZedThread.Message.AgentMessage(
				content: content
			))
		}
	}
}
