import ArgumentParser
import Foundation
import SwiftPizzaSnips
import ZedChatLib

struct ExtractJSONBlobs: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "extract-json-blobs",
		abstract: "Dumps the entire library of decompressed json into a folder")

	@Argument(help: "Directory to dump json into", transform: {
		URL(filePath: $0)
	})
	var output: URL

	@Flag(name: [.customShort("f"), .customLong("filter")], help: "Filter into folders by model versions")
	private var _shouldFilterByModelVersion: Int
	var shouldFilterByModelVersion: Bool { _shouldFilterByModelVersion == 1 }

	private static let dateReader = ISO8601DateFormatter().with {
		$0.formatOptions = .withInternetDateTime
		$0.formatOptions.insert(.withFractionalSeconds)
	}
	private static let dateFormatter = DateFormatter().with {
		$0.dateFormat = "yyyy-MM-dd_HH-mm-ss"
	}

	func run() async throws {
		try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

		let dbAccessor = ZedThreadsInterface()

		let rawThreads = try await dbAccessor.fetchAllThreads(limit: nil)

		func getVersion(from jsonObject: [String: Any]?) -> String? {
			guard let version = jsonObject?["version"] as? String else { return nil }
			return version
		}

		for thread in rawThreads {
			guard
				let jsonData = thread.rawMessageThreadJSON()
			else {
				print("🛑 Error extracting message thread json from \(thread.id ?? "no id"): \(thread.summary)")
				continue
			}

			let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
			let cleanJSON = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])

			let dateString = {
				guard let actualDate = Self.dateReader.date(from: thread.updatedAt) else {
					return thread.updatedAt.replacingOccurrences(of: ":", with: "-")
				}
				return Self.dateFormatter.string(from: actualDate).replacingOccurrences(of: ":", with: "-")
			}()

			let filename = "\(dateString)_\(thread.id, default: "no id")_\(thread.summary.prefix(20)).threadmessages"
				.replacingOccurrences(of: "/", with: "_")
			print(filename)

			if shouldFilterByModelVersion {
				let version = getVersion(from: jsonObject as? [String: Any])
				
				let versionDirectory = output.appending(component: version ?? "Unknown version", directoryHint: .isDirectory)

				try FileManager.default.createDirectory(at: versionDirectory, withIntermediateDirectories: true)
				let outputURL = versionDirectory.appending(component: filename)
				try cleanJSON.write(to: outputURL)
			} else {
				let outputURL = output.appending(component: filename)
				try cleanJSON.write(to: outputURL)
			}
		}
	}
}
