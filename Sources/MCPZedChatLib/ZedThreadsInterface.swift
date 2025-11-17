import Foundation
import SQLite3
import SwiftPizzaSnips
import libzstd
import Algorithms

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

	func searchThreadContent(for query: String, caseInsensitive: Bool, page: Int, onlyFirstMatchPerThread: Bool) async throws -> [Threads.ContentResult] {
		guard page >= 0 else { return [] }
		let allThreads = try await fetchAllThreads(limit: nil)

		let matches = await allThreads.asyncConcurrentMap { thread in
			let consumable = await thread.consumableWithContent

			let results: [(index: Int, message: ZedThread.Message)]
			if onlyFirstMatchPerThread {
				results = [consumable?.thread?.nextMessage(containing: query, caseInsensitive: caseInsensitive)].compactMap(\.self)
			} else {
				results = consumable?.thread?.messages(containing: query, caseInsensitive: caseInsensitive) ?? []
			}

			let contentResults = results.compactMap { result -> Threads.ContentResult? in
				// Extract text content from message
				let messageText = result.message.textContent
				guard !messageText.isEmpty else { return nil }
				
				// Find the match position in the text
				let searchOptions: String.CompareOptions = caseInsensitive ? [.caseInsensitive] : []
				guard let matchRange = messageText.range(of: query, options: searchOptions) else {
					return nil
				}
				
				let matchPosition = messageText.distance(from: messageText.startIndex, to: matchRange.lowerBound)
				
				// Extract context (100 chars before and after)
				let contextSize = 100
				let beforeStart = messageText.index(matchRange.lowerBound, offsetBy: -contextSize, limitedBy: messageText.startIndex) ?? messageText.startIndex
				let afterEnd = messageText.index(matchRange.upperBound, offsetBy: contextSize, limitedBy: messageText.endIndex) ?? messageText.endIndex
				
				let contextBefore = String(messageText[beforeStart..<matchRange.lowerBound])
				let matchText = String(messageText[matchRange])
				let contextAfter = String(messageText[matchRange.upperBound..<afterEnd])
				
				// Determine message role
				let role: String
				switch result.message {
				case .user: role = "user"
				case .agent: role = "assistant"
				case .noop: role = "noop"
				}
				
				return Threads.ContentResult(
					threadID: consumable?.id,
					threadSummary: consumable?.summary,
					threadMessageCount: consumable?.thread?.messageCount ?? 0,
					messageIndex: result.index,
					matchPosition: matchPosition,
					contextBefore: contextBefore,
					matchText: matchText,
					contextAfter: contextAfter,
					messageRole: role)
			}

			return contentResults
		}

		let allMatches = matches.flatMap(\.self)

		let pages = allMatches.lazy.chunks(ofCount: 10)

		guard page < pages.count else { return [] }

		return Array(pages[_offset: page])
	}
}

extension Threads {
	struct Consumable: Codable, Sendable {
		let id: String?
		let summary: String
		let lastUpdate: Date
		let thread: ZedThread?
	}

	struct ContentResult: Codable, Sendable {
		let threadID: String?
		let threadSummary: String?
		let threadMessageCount: Int
		let messageIndex: Int
		let matchPosition: Int
		let contextBefore: String
		let matchText: String
		let contextAfter: String
		let messageRole: String
	}

	@MainActor
	static private let dateFormatter = ISO8601DateFormatter().with {
		$0.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
	}

	@MainActor
	var consumable: Consumable? {
		.init(
			id: id,
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
			id: id,
			summary: summary,
			lastUpdate: Self.dateFormatter.date(from: updatedAt) ?? .now,
			thread: parsedThread)
	}

	func consumableWithContent(withMessageRange messageRange: Range<Int>?, andFilters: [ThreadFilter]) async -> Consumable? {
		guard let decompressed = decompressZstd(dataAsData) else {
			return nil
		}

		// Parse JSON into ZedThread structure
		var parsedThread: ZedThread?
		do {
			parsedThread = try JSONDecoder().decode(ZedThread.self, from: decompressed)
		} catch {
			// If JSON parsing fails, return nil
			print("Error: \(error)")
			parsedThread = nil
		}

		for andFilter in andFilters {
			parsedThread = parsedThread?.addingFilter(andFilter)
		}

		if let messageRange {
			parsedThread = parsedThread?.clampingToMessageRange(messageRange)
		}

		let date = await Self.dateFormatter.date(from: updatedAt) ?? .now

		return .init(
			id: id,
			summary: summary,
			lastUpdate: date,
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
