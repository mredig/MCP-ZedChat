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

	func fetchAllThreads(limit: Int?) async throws -> [Threads] {
		try await db.threads.fetch(limit: limit, orderBy: \.updatedAt, .descending)
	}

	func fetchThread(id: String) async throws -> Threads {
		try await db.threads.find(id).unwrap("No thread found matching id \(id)")
	}

	func searchThreadTitles(for query: String, limit: Int?) throws -> [Threads] {
		try db.threads.fetch(limit: limit, orderBy: \.updatedAt, .descending) {
			$0.summary.contains(query, caseInsensitive: true)
		}
	}

	func searchThreadContent(for query: String, limit: Int?) async throws -> [Threads] {
		let allThreads = try await fetchAllThreads(limit: nil)
		let regex = Regex {
			query
		}.ignoresCase()

		let matchingThreads = await allThreads.asyncFilter { thread in
			let consumable = await thread.consumableWithContent

			return consumable?.thread?.nextMessage(containing: query, caseInsensitive: true) != nil
		}

		return matchingThreads
	}
}

extension Threads {
	struct Consumable: Codable, Sendable {
		let id: UUID?
		let summary: String
		let lastUpdate: Date
		let thread: ZedThread?
		
//		/// Convenience accessor for thread content as plain text
//		var contentText: String? {
//			thread?.allTextContent
//		}
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
			thread: nil)
	}

	@MainActor
	var consumableWithContent: Consumable? {
		guard let decompressed = decompressZstd(dataAsData) else {
			return nil
		}
		
		// Parse JSON into ZedThread structure
		let parsedThread: ZedThread?
		do {
			parsedThread = try JSONDecoder().decode(ZedThread.self, from: decompressed)
		} catch {
			// If JSON parsing fails, return nil
			print("Error: \(error)")
			parsedThread = nil
		}

		return .init(
			id: uuid,
			summary: summary,
			lastUpdate: Self.dateFormatter.date(from: updatedAt) ?? .now,
			thread: parsedThread)
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
			var iterations = 0
			let maxIterations = 10000 // Prevent infinite loops

			while srcPos < srcSize && iterations < maxIterations {
				iterations += 1
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

					let remainingOutput = currentBufferSize - totalDecompressed
					let remainingInput = srcSize - currentSrcPos

					// Validate values are non-negative before size_t conversion
					guard remainingOutput >= 0 else { return (-1, 0) }
					guard remainingInput >= 0 else { return (-1, 0) }

					// Validate pointer arithmetic won't overflow
					guard totalDecompressed <= Int.max - MemoryLayout<UInt8>.stride else { return (-1, 0) }
					guard currentSrcPos <= Int.max - MemoryLayout<UInt8>.stride else { return (-1, 0) }

					// Validate advanced pointers stay within bounds
					guard totalDecompressed <= currentBufferSize else { return (-1, 0) }
					guard currentSrcPos <= srcSize else { return (-1, 0) }

					var outBuf = ZSTD_outBuffer(
						dst: dstAddress.advanced(by: totalDecompressed),
						size: size_t(remainingOutput),
						pos: 0
					)

					var inBuf = ZSTD_inBuffer(
						src: srcAddress.advanced(by: currentSrcPos),
						size: size_t(remainingInput),
						pos: 0
					)

					let ret = ZSTD_decompressStream(dctx, &outBuf, &inBuf)

					// Check for error
					if ZSTD_isError(ret) != 0 {
						return (-1, 0)
					}

					// Validate return values are reasonable (not larger than buffer sizes)
					guard outBuf.pos <= size_t(remainingOutput) else { return (-1, 0) }
					guard inBuf.pos <= size_t(remainingInput) else { return (-1, 0) }

					// Validate size_t to Int conversion won't overflow
					// (These checks are platform-dependent but safe on all architectures)
					#if arch(i386) || arch(arm)
					// On 32-bit platforms, size_t could potentially exceed Int.max
					guard outBuf.pos <= Int.max else { return (-1, 0) }
					guard inBuf.pos <= Int.max else { return (-1, 0) }
					#endif

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

				// If no more input consumed and output written is also 0, we're stuck
				// (zstd can legitimately consume 0 bytes while producing output)
				if result.consumed == 0 && result.written == 0 && srcPos < srcSize {
					return nil // Incomplete decompression - stuck state
				}
			}

			// Check if we hit iteration limit
			guard iterations < maxIterations else {
				return nil // Decompression took too many iterations
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
