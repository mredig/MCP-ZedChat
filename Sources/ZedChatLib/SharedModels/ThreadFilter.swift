public enum ThreadFilter: Sendable {
	case voice(Voice)
	case query(String)
	case isTool(Bool)
	case isThinking(Bool)

	public enum Voice: Sendable {
		case user
		case agent
	}
}
