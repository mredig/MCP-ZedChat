import ArgumentParser
import Foundation
import ZedChatLib

struct GetMessage: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "get-message",
		abstract: "Get a specific message within a thread")

	@Argument(help: "The thread id that the message resides within")
	var threadID: String

	@Argument(help: "The index of the message within the thread")
	var messageIndex: Int


	func run() async throws {
		let dbAccessor = ZedThreadsInterface()

		guard
			let threadContent = try await dbAccessor.fetchThreadContent(id: threadID.lowercased())
		else { throw ZedChatError.contentError(message: "Failed to load content") }

		guard messageIndex < threadContent.messages.count else {
			throw ZedChatError.contentError(message: "\(messageIndex) out of range (thread has \(threadContent.messages.count) messages")
		}

		let message = threadContent.messages[messageIndex]

		let fullText = message.textContent

		let role: String
		switch message {
		case .user:
			role = "user"
		case .agent:
			role = "assistant"
		case .noop:
			role = "noop"
		}

		print("(\(role)): ")
		print(fullText)
	}
}
