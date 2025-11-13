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
			
			// Handle empty input
			let srcSize = compressedData.count
			guard srcSize > 0 else {
				return Data() // Empty input returns empty output
			}
			
			// Start with a reasonable buffer size (check for overflow)
			let (safeInitialSize, overflow) = srcSize.multipliedReportingOverflow(by: 3)
			guard !overflow, safeInitialSize > 0 else {
				return nil
			}
			let initialBufferSize = max(safeInitialSize, 4096)
			var outputBuffer = Data(count: initialBufferSize)
			var totalDecompressed = 0
			
			// Use streaming decompression
			var srcPos = 0
			
			while srcPos < srcSize {
				// Check if we need to grow buffer BEFORE attempting to write
				// Protect against underflow when outputBuffer.count < 1024
				let availableSpace = outputBuffer.count > totalDecompressed ? outputBuffer.count - totalDecompressed : 0
				if availableSpace < 1024 {
					// Check for overflow before doubling
					let (newSize, overflow) = outputBuffer.count.multipliedReportingOverflow(by: 2)
					guard !overflow, newSize > outputBuffer.count else {
						return nil // Buffer too large
					}
					outputBuffer.count = newSize
				}
				
				let currentBufferSize = outputBuffer.count
				let currentSrcPos = srcPos // Capture before closure to avoid mutation
				
				let result = outputBuffer.withUnsafeMutableBytes { (outputPtr: UnsafeMutableRawBufferPointer) -> (written: Int, consumed: Int) in
					guard let dstAddress = outputPtr.baseAddress else { return (-1, 0) }
					
					// Bounds check: ensure we're not advancing beyond allocated memory
					guard totalDecompressed < currentBufferSize else { return (-1, 0) }
					guard currentSrcPos < srcSize else { return (-1, 0) }
					
					// Additional safety: ensure we have space for at least 1 byte
					guard currentBufferSize > totalDecompressed else { return (-1, 0) }
					guard srcSize > currentSrcPos else { return (-1, 0) }
					
					let remainingOutput = currentBufferSize - totalDecompressed
					let remainingInput = srcSize - currentSrcPos
					
					var outBuf = ZSTD_outBuffer(
						dst: dstAddress.advanced(by: totalDecompressed),
						size: remainingOutput,
						pos: 0
					)
					
					var inBuf = ZSTD_inBuffer(
						src: srcAddress.advanced(by: currentSrcPos),
						size: remainingInput,
						pos: 0
					)
					
					let ret = ZSTD_decompressStream(dctx, &outBuf, &inBuf)
					
					// Check for error
					if ZSTD_isError(ret) != 0 {
						return (-1, 0)
					}
					
					// Validate return values are reasonable (not larger than buffer sizes)
					guard outBuf.pos <= remainingOutput else { return (-1, 0) }
					guard inBuf.pos <= remainingInput else { return (-1, 0) }
					
					return (Int(outBuf.pos), Int(inBuf.pos))
				}
				
				if result.written < 0 {
					return nil
				}
				
				// Check for overflow when adding written bytes
				let (newTotal, overflowTotal) = totalDecompressed.addingReportingOverflow(result.written)
				guard !overflowTotal, newTotal <= outputBuffer.count else {
					return nil // Overflow or buffer overrun
				}
				totalDecompressed = newTotal
				
				// Check for overflow when advancing source position
				let (newSrcPos, overflowSrc) = srcPos.addingReportingOverflow(result.consumed)
				guard !overflowSrc, newSrcPos <= srcSize else {
					return nil // Overflow or read beyond buffer
				}
				srcPos = newSrcPos
				
				// If no more input consumed and we haven't processed everything, we're stuck
				if result.consumed == 0 && srcPos < srcSize {
					break
				}
			}
			
			// Trim to actual size (final safety check)
			guard totalDecompressed <= outputBuffer.count else {
				return nil // Safety: don't trim beyond allocated size
			}
			outputBuffer.count = totalDecompressed
			return outputBuffer
		}
	}
}
