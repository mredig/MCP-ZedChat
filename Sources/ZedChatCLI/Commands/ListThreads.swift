import ArgumentParser
import Foundation
import ZedChatLib

struct ListThreads: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "list-threads",
		abstract: "List all the threads")

	@Option(help: "Limit how many threads to list")
	var limit: Int?

	func run() async throws {
		let dbAccessor = ZedThreadsInterface()

		let rawThreads = try await dbAccessor.fetchAllThreads(limit: limit)

		for thread in rawThreads {
			print(thread)
		}
	}
}
