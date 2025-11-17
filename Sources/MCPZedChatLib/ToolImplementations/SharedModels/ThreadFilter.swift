enum ThreadFilter {
	case voice(Voice)
	case query(String)
	case isTool(Bool)
	case isThinking(Bool)

	enum Voice {
		case user
		case agent
	}
}
