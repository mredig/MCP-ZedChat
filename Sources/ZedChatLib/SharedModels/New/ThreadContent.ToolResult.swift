extension ThreadContent {
	public struct ToolResult: Codable, Sendable {
		public let content: [Content]?
		public let toolUseID: String
		public let toolName: String?
		public let isError: Bool?

		enum CodingKeys: String, CodingKey {
			case content
			case isError = "is_error"
			case toolUseID = "tool_use_id"
			case toolName = "tool_name"
		}

		public enum Content: Codable, Sendable {
			case text(String)
			case image(ImageContent)

			public struct ImageContent: Codable, Sendable {
				public let data: String
				public let mimeType: String

				enum CodingKeys: String, CodingKey {
					case data
					case mimeType = "mime_type"
				}
			}

			public init(from decoder: Decoder) throws {
				let container = try decoder.singleValueContainer()
				let dict = try container.decode([String: AnyCodable].self)

				if let text = dict["Text"]?.value as? String {
					self = .text(text)
				} else if let imageData = dict["Image"] {
					let image = try imageData.decode(ImageContent.self)
					self = .image(image)
				} else {
					throw DecodingError.dataCorruptedError(
						in: container,
						debugDescription: "ToolResultContent must contain either 'text' or 'image' key"
					)
				}
			}

			public func encode(to encoder: Encoder) throws {
				var container = encoder.singleValueContainer()
				switch self {
				case .text(let text):
					try container.encode(["text": text])
				case .image(let image):
					try container.encode(["image": image])
				}
			}
		}

		init(content: [Content]?, toolUseID: String, toolName: String?, isError: Bool?) {
			self.content = content
			self.toolUseID = toolUseID
			self.toolName = toolName
			self.isError = isError
		}

		public init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let content: [Content]?
			do {
				let tContent = try container.decodeIfPresent(Content.self, forKey: .content)
				content = tContent.map { [$0] }
			} catch {
				content = try container.decodeIfPresent([Content].self, forKey: .content)
			}
			self.content = content
			self.isError = try container.decodeIfPresent(Bool.self, forKey: .isError)
			self.toolUseID = try container.decode(String.self, forKey: .toolUseID)
			self.toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
		}
	}
}
