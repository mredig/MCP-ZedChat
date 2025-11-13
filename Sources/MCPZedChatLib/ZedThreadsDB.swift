import Foundation
import SQLite3

/// Zed Threads Database Schema
/// Location: ~/Library/Application Support/Zed/threads/threads.db
struct ZedThreadsDB {
    
    /// Thread record from Zed's threads database
    struct Thread: Codable, Identifiable, Sendable {
        let id: String
        let summary: String
        let updatedAt: String
        let dataType: String
        let data: Data
        
        enum CodingKeys: String, CodingKey {
            case id
            case summary
            case updatedAt = "updated_at"
            case dataType = "data_type"
            case data
        }
    }
    
    /// Database connection wrapper
    actor Connection {
        private nonisolated(unsafe) let db: OpaquePointer?
        private let path: String
        
        init(path: String = NSHomeDirectory() + "/Library/Application Support/Zed/threads/threads.db") throws {
            self.path = path
            
            var db: OpaquePointer?
            let result = sqlite3_open_v2(
                path,
                &db,
                SQLITE_OPEN_READONLY,
                nil
            )
            
            guard result == SQLITE_OK else {
                sqlite3_close(db)
                throw DatabaseError.openFailed(code: result, message: String(cString: sqlite3_errmsg(db)))
            }
            
            self.db = db
        }
        
        deinit {
            sqlite3_close(db)
        }
        
        /// Fetch all threads
        func fetchAllThreads() throws -> [Thread] {
            guard let db = db else {
                throw DatabaseError.notConnected
            }
            
            let query = "SELECT id, summary, updated_at, data_type, data FROM threads ORDER BY updated_at DESC"
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(statement) }
            
            var threads: [Thread] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let summary = String(cString: sqlite3_column_text(statement, 1))
                let updatedAt = String(cString: sqlite3_column_text(statement, 2))
                let dataType = String(cString: sqlite3_column_text(statement, 3))
                
                let dataBlob = sqlite3_column_blob(statement, 4)
                let dataSize = sqlite3_column_bytes(statement, 4)
                let data = Data(bytes: dataBlob!, count: Int(dataSize))
                
                threads.append(Thread(
                    id: id,
                    summary: summary,
                    updatedAt: updatedAt,
                    dataType: dataType,
                    data: data
                ))
            }
            
            return threads
        }
        
        /// Fetch a specific thread by ID
        func fetchThread(id: String) throws -> Thread? {
            guard let db = db else {
                throw DatabaseError.notConnected
            }
            
            let query = "SELECT id, summary, updated_at, data_type, data FROM threads WHERE id = ?"
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, id, -1, nil)
            
            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }
            
            let threadId = String(cString: sqlite3_column_text(statement, 0))
            let summary = String(cString: sqlite3_column_text(statement, 1))
            let updatedAt = String(cString: sqlite3_column_text(statement, 2))
            let dataType = String(cString: sqlite3_column_text(statement, 3))
            
            let dataBlob = sqlite3_column_blob(statement, 4)
            let dataSize = sqlite3_column_bytes(statement, 4)
            let data = Data(bytes: dataBlob!, count: Int(dataSize))
            
            return Thread(
                id: threadId,
                summary: summary,
                updatedAt: updatedAt,
                dataType: dataType,
                data: data
            )
        }
        
        /// Search threads by summary text
        func searchThreads(query: String) throws -> [Thread] {
            guard let db = db else {
                throw DatabaseError.notConnected
            }
            
            let sql = "SELECT id, summary, updated_at, data_type, data FROM threads WHERE summary LIKE ? ORDER BY updated_at DESC"
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(message: String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(statement) }
            
            let searchPattern = "%\(query)%"
            sqlite3_bind_text(statement, 1, searchPattern, -1, nil)
            
            var threads: [Thread] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let summary = String(cString: sqlite3_column_text(statement, 1))
                let updatedAt = String(cString: sqlite3_column_text(statement, 2))
                let dataType = String(cString: sqlite3_column_text(statement, 3))
                
                let dataBlob = sqlite3_column_blob(statement, 4)
                let dataSize = sqlite3_column_bytes(statement, 4)
                let data = Data(bytes: dataBlob!, count: Int(dataSize))
                
                threads.append(Thread(
                    id: id,
                    summary: summary,
                    updatedAt: updatedAt,
                    dataType: dataType,
                    data: data
                ))
            }
            
            return threads
        }
    }
    
    /// Database errors
    enum DatabaseError: Error, CustomStringConvertible {
        case notConnected
        case openFailed(code: Int32, message: String)
        case queryFailed(message: String)
        
        var description: String {
            switch self {
            case .notConnected:
                return "Database not connected"
            case .openFailed(let code, let message):
                return "Failed to open database (code \(code)): \(message)"
            case .queryFailed(let message):
                return "Query failed: \(message)"
            }
        }
    }
}