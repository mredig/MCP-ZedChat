import Foundation

// MARK: - Helper Type for Dynamic JSON

/// Type-erased wrapper for decoding heterogeneous JSON
public struct AnyCodable: Codable, @unchecked Sendable {
	public let value: Any

	public init(_ value: Any) {
		self.value = value
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		if let bool = try? container.decode(Bool.self) {
			value = bool
		} else if let int = try? container.decode(Int.self) {
			value = int
		} else if let double = try? container.decode(Double.self) {
			value = double
		} else if let string = try? container.decode(String.self) {
			value = string
		} else if let array = try? container.decode([AnyCodable].self) {
			value = array.map(\.value)
		} else if let dict = try? container.decode([String: AnyCodable].self) {
			value = dict.mapValues(\.value)
		} else if container.decodeNil() {
			value = Optional<Any>.none as Any
		} else {
			throw DecodingError.dataCorruptedError(
				in: container,
				debugDescription: "Unable to decode value"
			)
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()

		switch value {
		case let bool as Bool:
			try container.encode(bool)
		case let int as Int:
			try container.encode(int)
		case let double as Double:
			try container.encode(double)
		case let string as String:
			try container.encode(string)
		case let array as [Any]:
			try container.encode(array.map { AnyCodable($0) })
		case let dict as [String: Any]:
			try container.encode(dict.mapValues { AnyCodable($0) })
		default:
			if case Optional<Any>.none = value {
				try container.encodeNil()
			} else {
				throw EncodingError.invalidValue(
					value,
					EncodingError.Context(
						codingPath: encoder.codingPath,
						debugDescription: "Unable to encode value of type \(type(of: value))"
					)
				)
			}
		}
	}

	private static let roundtripEncoder = JSONEncoder()
	private static let roundtripDecoder = JSONDecoder()

	func decode<T: Decodable>(_ type: T.Type) throws -> T {
		let data = try Self.roundtripEncoder.encode(self)
		return try Self.roundtripDecoder.decode(T.self, from: data)
	}
}
