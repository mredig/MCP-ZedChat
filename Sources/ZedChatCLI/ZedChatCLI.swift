import ArgumentParser
import Foundation
import ZedChatLib

@main
struct ZedChatCLI: AsyncParsableCommand {
	static let configuration: CommandConfiguration = .init(
		version: "0.0.1",
		commandName: "zedhist",
		subcommands: [
			ListThreads.self,
			GetMessage.self,
			ExtractJSONBlobs.self,
			Troubleshoot.self,
		])
}
