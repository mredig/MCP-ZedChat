import Foundation
import SQLite3
import SwiftPizzaSnips
import libzstd

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
		let decompressed = decompressZstd(dataAsData)
		
		let contentString = decompressed.map { String(decoding: $0, as: UTF8.self) }

		return .init(
			id: uuid,
			summary: summary,
			lastUpdate: Self.dateFormatter.date(from: updatedAt) ?? .now,
			content: contentString)
	}
	
	private func decompressZstd(_ compressedData: Data) -> Data? {
		return compressedData.withUnsafeBytes { (compressedPtr: UnsafeRawBufferPointer) -> Data? in
			guard let baseAddress = compressedPtr.baseAddress else { return nil }
			
			// Get decompressed size
			let decompressedSize = ZSTD_getFrameContentSize(baseAddress, compressedData.count)
			
			guard decompressedSize != ZSTD_CONTENTSIZE_ERROR,
				  decompressedSize != ZSTD_CONTENTSIZE_UNKNOWN else {
				return nil
			}
			
			// Allocate buffer for decompressed data
			var decompressedData = Data(count: Int(decompressedSize))
			
			let actualSize = decompressedData.withUnsafeMutableBytes { (decompressedPtr: UnsafeMutableRawBufferPointer) -> Int in
				guard let destAddress = decompressedPtr.baseAddress else { return 0 }
				
				return ZSTD_decompress(
					destAddress,
					Int(decompressedSize),
					baseAddress,
					compressedData.count
				)
			}
			
			// Check for errors
			if ZSTD_isError(actualSize) != 0 {
				return nil
			}
			
			return decompressedData
		}
	}
}
