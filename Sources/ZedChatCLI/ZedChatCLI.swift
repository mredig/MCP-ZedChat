import ArgumentParser
import Foundation
import ZedChatLib

@main
struct ZedChatCLI: AsyncParsableCommand {
	@Argument(help: "search query")
	var search: String

	func run() async throws {

	}
}
