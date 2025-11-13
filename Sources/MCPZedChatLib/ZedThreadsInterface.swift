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
		// Create decompression context
		guard let dctx = ZSTD_createDCtx() else {
			return nil
		}
		defer { ZSTD_freeDCtx(dctx) }
		
		return compressedData.withUnsafeBytes { (compressedPtr: UnsafeRawBufferPointer) -> Data? in
			guard let srcAddress = compressedPtr.baseAddress else { return nil }
			
			// Start with a reasonable buffer size
			let initialBufferSize = max(compressedData.count * 3, 4096)
			var outputBuffer = Data(count: initialBufferSize)
			var totalDecompressed = 0
			
			// Use streaming decompression
			var srcPos = 0
			let srcSize = compressedData.count
			
			while srcPos < srcSize {
				let currentBufferSize = outputBuffer.count
				let result = outputBuffer.withUnsafeMutableBytes { (outputPtr: UnsafeMutableRawBufferPointer) -> Int in
					guard let dstAddress = outputPtr.baseAddress else { return 0 }
				
					var outBuf = ZSTD_outBuffer(
						dst: dstAddress.advanced(by: totalDecompressed),
						size: currentBufferSize - totalDecompressed,
						pos: 0
					)
					
					var inBuf = ZSTD_inBuffer(
						src: srcAddress.advanced(by: srcPos),
						size: srcSize - srcPos,
						pos: 0
					)
					
					let ret = ZSTD_decompressStream(dctx, &outBuf, &inBuf)
					
					// Check for error
					if ZSTD_isError(ret) != 0 {
						return -1
					}
					
					srcPos += inBuf.pos
					return Int(outBuf.pos)
				}
				
				if result < 0 {
					return nil
				}
				
				totalDecompressed += result
				
				// If we're out of output space, grow the buffer
				if totalDecompressed >= outputBuffer.count - 1024 {
					outputBuffer.count = outputBuffer.count * 2
				}
				
				// If no more input consumed, we're done or stuck
				if result == 0 && srcPos < srcSize {
					break
				}
			}
			
			// Trim to actual size
			outputBuffer.count = totalDecompressed
			return outputBuffer
		}
	}
}
