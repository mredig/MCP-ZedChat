public enum ThreadFilter: Sendable {
	case voice(Voice)
	case query(String, caseInsensitive: Bool)
	case isTool(Bool)
	case isThinking(Bool)

	static func query(_ query: String) -> ThreadFilter {
		.query(query, caseInsensitive: true)
	}

	public enum Voice: Sendable {
		case user
		case agent
	}
}
