import ArgumentParser
import Foundation
import SwiftPizzaSnips
import ZedChatLib

struct ExtractJSON: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "extract-json",
		abstract: "Extract raw json to a file on disk")

	@Option(
		name: [.long, .short],
		help: "The file destination. If ommitted, will output to `threadid.json` in the current directory",
		transform: {
			URL(filePath: $0)
		})
	var output: URL?

	@Flag(name: [.long, .short])
	var prettyJSON = false

	@Flag(name: [.long, .short])
	var sortKeys = false

	@Argument(help: "The thread id you wish to extract", transform: {
		$0.lowercased()
	})
	var threadID: String

	func run() async throws {
		let dbAccessor = ZedThreadsInterface()

		let thread = try await dbAccessor.fetchThread(id: threadID)
		guard let data = thread.rawMessageThreadJSON() else {
			throw MetaThread.ThreadError.missingContentData
		}

		let outData = try {
			var options: JSONSerialization.WritingOptions = []
			guard prettyJSON || sortKeys else {
				return data
			}
			let tJSONObject = try JSONSerialization.jsonObject(with: data, options: .json5Allowed)
			if prettyJSON { options.insert(.prettyPrinted) }
			if sortKeys { options.insert(.sortedKeys) }

			return try JSONSerialization.data(withJSONObject: tJSONObject, options: options)
		}()

		let outputURL: URL
		let parentDir: URL
		if let output {
			if output.hasDirectoryPath {
				parentDir = output
				outputURL = parentDir
					.appending(component: threadID)
					.appendingPathExtension("json")
			} else {
				parentDir = output.deletingLastPathComponent()
				outputURL = output
			}
		} else {
			parentDir = .currentDirectory()
			outputURL = parentDir
				.appending(component: threadID)
				.appendingPathExtension("json")
		}

		try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

		try outData.write(to: outputURL)
	}
}
