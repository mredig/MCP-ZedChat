import ArgumentParser
import Foundation
import SwiftPizzaSnips
import ZedChatLib

struct Troubleshoot: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "troubleshoot",
		abstract: "Perform some troubleshooting analysis",
		subcommands: [
			DecodeStressTest.self,
			ExtractJSON.self,
		])
}
