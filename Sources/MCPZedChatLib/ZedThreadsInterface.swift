import Foundation
import SQLite3
import SwiftPizzaSnips

struct ZedThreadsInterface {
	let db: ThreadsDB

	init() {
		let threadsDBFilePath = URL
			.homeDirectory
			.appending(components: "Library", "Application Support", "Zed", "threads")
			.appending(component: "threads")
			.appendingPathExtension("db")
		self.db = ThreadsDB(url: threadsDBFilePath, readOnly: true)
	}

	func fetchAllThreads() async throws -> [Threads] {
		try await db.threads.fetch().sorted(by: { $0.updatedAt > $1.updatedAt })
	}

	func fetchThread(id: UUID) async throws -> Threads {
		try await db.threads.find(id.uuidString.lowercased()).unwrap("No thread found matching id \(id)")
	}

	func searchThreadTitles(for query: String) throws -> [Threads] {
		try db.threads.filter {
			$0.summary.lowercased().contains(query)
		}
	}
}

extension Threads {
	struct Consumable: Codable, Sendable {
		let id: UUID?
		let summary: String
		let lastUpdate: Date
		let content: String?
	}

	@MainActor
	static private let dateFormatter = ISO8601DateFormatter().with {
		$0.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	}

	@MainActor
	var consumable: Consumable? {
		.init(
			id: uuid,
			summary: summary,
			lastUpdate: Self.dateFormatter.date(from: updatedAt) ?? .now,
			content: nil)
	}


	@MainActor
	var consumableWithContent: Consumable? {
		.init(
			id: uuid,
			summary: summary,
			lastUpdate: Self.dateFormatter.date(from: updatedAt) ?? .now,
			content: "TBD")
	}
}
