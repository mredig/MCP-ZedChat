import ArgumentParser
import Foundation
import SwiftPizzaSnips
import ZedChatLib

struct DecodeStressTest: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "decode-stress",
		abstract: "Attempt to decode all message histories in the db and report errors")

	@Flag(name: [.long, .customShort("u")])
	var summarize = false

	@Flag(name: [.customShort("s"), .customLong("success")])
	var reportSuccesses = false

	private static let decoder = JSONDecoder()

	func run() async throws {
		let dbAccessor = ZedThreadsInterface()

		let rawThreads = try await dbAccessor.fetchAllThreads(limit: nil)

		var successfulDecodes = 0
		var failedDecodes = 0
		var missingData = 0

		for thread in rawThreads {
			guard
				let jsonData = thread.rawMessageThreadJSON()
			else {
				print("No data for \(thread.id, default: "No id") - \(thread.summary)")
				missingData += 1
				continue
			}

			do {
				_ = try Self.decoder.decode(ThreadContent.self, from: jsonData)
				guard reportSuccesses else { continue }
				print("✅ \(thread.id, default: "No id") - \(thread.summary)")
				successfulDecodes += 1
			} catch {
				print("🔴 Error decoding: \(error) (\(thread.id, default: "No id") - \(thread.summary))")
				failedDecodes += 1
			}
		}

		guard summarize else { return }

		print("\n------------\n")
		print("Summary:\n✅ - \(successfulDecodes) successes\n🔴 - \(failedDecodes) decode failures\n🔴 - \(missingData) missing data")
	}
}
