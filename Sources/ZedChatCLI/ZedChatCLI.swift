import ArgumentParser
import Foundation
import ZedChatLib

@main
struct ZedChatCLI: AsyncParsableCommand {
	static let configuration: CommandConfiguration = .init(
		commandName: "zedchatcli",
		version: "0.0.1",
		subcommands: [
			ListThreads.self
		])
}
