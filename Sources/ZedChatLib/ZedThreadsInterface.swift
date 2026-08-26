import Foundation
import SQLite3
import SwiftPizzaSnips
import Algorithms

public struct ZedThreadsInterface: Sendable {
	let db: ZedDB

	// Cache for decompressed thread content (NSCache is thread-safe)
	private let threadCache: ThreadCache

	// Thread-safe cache wrapper
	private final class ThreadCache: @unchecked Sendable {
		private let cache = NSCache<NSString, CachedThreadContent>()

		init() {
			cache.countLimit = 500 // Cache up to 500 threads
			cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB limit
		}

		func object(forKey key: NSString) -> CachedThreadContent? {
			cache.object(forKey: key)
		}

		func setObject(_ obj: CachedThreadContent, forKey key: NSString, cost: Int) {
			cache.setObject(obj, forKey: key, cost: cost)
		}

		/// Create cache key from thread ID and updated timestamp
		static func makeCacheKey(threadID: String, updatedAt: String) -> NSString {
			"\(threadID)-\(updatedAt)" as NSString
		}
	}

	// Wrapper class for NSCache (must be a class, not a struct)
	private final class CachedThreadContent: @unchecked Sendable {
//		let consumable: MetaThread.ThreadItem
//
//		init(consumable: MetaThread.ThreadItem) {
//			self.consumable = consumable
//		}
		let content: ThreadContent

		init(content: ThreadContent) {
			self.content = content
		}
	}

	public init() {
		let threadsDBFilePath = URL
			.homeDirectory
			.appending(components: "Library", "Application Support", "Zed", "threads")
			.appending(component: "threads")
			.appendingPathExtension("db")
		self.db = ZedDB(url: threadsDBFilePath, readOnly: true)
		self.threadCache = ThreadCache()
	}

	public func fetchAllThreads(limit: Int?) async throws -> [MetaThread] {
		try await db.threads.fetch(limit: limit, orderBy: \.updatedAt, .descending)
	}

	public func fetchThread(id: String) async throws -> MetaThread {
		try await db.threads.find(id).unwrap("No thread found matching id \(id)")
	}

	public func fetchThreadContent(id: String) async throws -> ThreadContent? {
		let thread = try await fetchThread(id: id)
		return try await getCachedThreadContent(for: thread)
	}

	public func searchThreadTitles(for query: String, limit: Int?) throws -> [MetaThread] {
		try db.threads.fetch(limit: limit, orderBy: \.updatedAt, .descending) {
			$0.summary.contains(query, caseInsensitive: true)
		}
	}

	public func searchThreadContent(
		for query: String,
		caseInsensitive: Bool,
		page: Int,
		onlyFirstMatchPerThread: Bool,
		scopedThreadIDs: Set<String>? = nil,
		excludeThreadIDs: Bool = false
	) async throws -> [MetaThread.ContentResult] {
		guard page >= 0 else { return [] }
		var allThreads = try await fetchAllThreads(limit: nil)

		// Apply thread filtering if scopeToThreadIDs is provided
		if let scopeToThreadIDs = scopedThreadIDs {
			if excludeThreadIDs {
				// Exclude these threads
				allThreads = allThreads.filter { thread in
					guard let threadID = thread.id else { return false }
					return !scopeToThreadIDs.contains(threadID)
				}
			} else {
				// Include only these threads
				allThreads = allThreads.filter { thread in
					guard let threadID = thread.id else { return false }
					return scopeToThreadIDs.contains(threadID)
				}
			}
		}

		let matches = await allThreads.asyncConcurrentMap { thread in
			let content: ThreadContent? = try? await self.getCachedThreadContent(for: thread)

			let results: [(index: Int, message: ThreadContent.Message)]
			if onlyFirstMatchPerThread {
				results = [content?.nextMessage(containing: query, caseInsensitive: caseInsensitive)].compactMap(\.self)
			} else {
				results = content?.messages(containing: query, caseInsensitive: caseInsensitive) ?? []
			}

			let contentResults = results.compactMap { result -> MetaThread.ContentResult? in
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

				return MetaThread.ContentResult(
					threadID: thread.id,
					threadSummary: thread.summary,
					threadMessageCount: content?.messageCount ?? 0,
					messageIndex: result.index,
					matchPosition: matchPosition,
					contextBefore: contextBefore,
					matchText: matchText,
					contextAfter: contextAfter,
					messageRole: result.message.role)
			}

			return contentResults
		}

		let allMatches = matches.flatMap(\.self)

		let pages = allMatches.lazy.chunks(ofCount: 10)

		guard
			let pageIndex = pages.index(pages.startIndex, offsetBy: page, limitedBy: pages.endIndex),
			pageIndex < pages.endIndex
		else { return [] }

		return Array(pages[pageIndex])
	}

	/// Get thread content from cache or decompress if not cached
	/// Uses composite key (threadID + updatedAt) to invalidate stale cache entries
	private func getCachedThreadContent(for thread: MetaThread) async throws(MetaThread.ThreadError) -> ThreadContent? {
		guard let threadID = thread.id else { return nil }

		// Create cache key with threadID + updatedAt to handle updates
		let cacheKey = ThreadCache.makeCacheKey(threadID: threadID, updatedAt: thread.updatedAt)

		// Check cache first - if hit, skip decompression entirely
		if let cached = threadCache.object(forKey: cacheKey) {
			return cached.content
		}

		// Cache miss or stale - decompress the thread
		let content = try await thread.threadContent()

		// Calculate approximate cost (characters + overhead)
		let cost = content.messages.reduce(0) { sum, msg in
			sum + msg.textContent.count
		}

		// Store in cache with composite key
		let cached = CachedThreadContent(content: content)
		threadCache.setObject(cached, forKey: cacheKey, cost: cost)

		return content
	}
}
