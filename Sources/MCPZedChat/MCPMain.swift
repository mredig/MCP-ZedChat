import ArgumentParser
import MCPZedChatLib
import ZedChatLib

@main
struct MCPZedChatMain: AsyncParsableCommand {
	static let configuration = CommandConfiguration(version: BuildInfo.version)

	func run() async throws {
		try await Entrypoint.run()
	}
}
