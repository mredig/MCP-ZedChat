import ArgumentParser
import MCPZedChatLib

@main
struct MCPZedChatMain: AsyncParsableCommand {
	func run() async throws {
		try await Entrypoint.run()
    }
}
