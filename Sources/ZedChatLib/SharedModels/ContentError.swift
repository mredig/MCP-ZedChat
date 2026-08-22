// MARK: - Content Error

public enum ZedChatError: Error {
	case missingArgument(String)
	case mismatchedType(argument: String, expected: String)
	case initializationFailed(String)
	case contentError(message: String?)
	case other(Error)
}
