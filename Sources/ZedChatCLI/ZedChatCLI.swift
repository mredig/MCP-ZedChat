import ArgumentParser
import Foundation
import ZedChatLib

@main
struct ZedChatCLI: AsyncParsableCommand {
	static let configuration: CommandConfiguration = .init(
		commandName: "zedhist",
		version: BuildInfo.version,
		subcommands: [
			ListThreads.self,
			GetMessage.self,
			ExtractJSONBlobs.self,
			Troubleshoot.self,
		])
}
