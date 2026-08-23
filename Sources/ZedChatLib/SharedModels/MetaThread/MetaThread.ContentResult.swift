extension MetaThread {
	public struct ContentResult: Codable, Sendable {
		public let threadID: String?
		public let threadSummary: String?
		public let threadMessageCount: Int
		public let messageIndex: Int
		public let matchPosition: Int
		public let contextBefore: String
		public let matchText: String
		public let contextAfter: String
		public let messageRole: String
	}
}
