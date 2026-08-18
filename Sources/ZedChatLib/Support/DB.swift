// Autocreated by sqlite2swift at 2025-11-13T07:28:11Z

import SQLite3
import Foundation
import Lighter

/**
 * Create a SQLite3 database
 * 
 * The database is created using the SQL `create` statements in the
 * Schema structures.
 * 
 * If the operation is successful, the open database handle will be
 * returned in the `db` `inout` parameter.
 * If the open succeeds, but the SQL execution fails, an incomplete
 * database can be left behind. I.e. if an error happens, the path
 * should be tested and deleted if appropriate.
 * 
 * Example:
 * ```swift
 * var db : OpaquePointer!
 * let rc = sqlite3_create_threadsdb(path, &db)
 * ```
 * 
 * - Parameters:
 *   - path: Path of the database.
 *   - flags: Custom open flags.
 *   - db: A SQLite3 database handle, if successful.
 * - Returns: The SQLite3 error code (`SQLITE_OK` on success).
 */
@inlinable
public func sqlite3_create_threadsdb(
  _ path: UnsafePointer<CChar>!,
  _ flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE,
  _ db: inout OpaquePointer?
) -> Int32
{
  let openrc = sqlite3_open_v2(path, &db, flags, nil)
  if openrc != SQLITE_OK {
    return openrc
  }
  let execrc = sqlite3_exec(db, ThreadsDB.creationSQL, nil, nil, nil)
  if execrc != SQLITE_OK {
    sqlite3_close(db)
    db = nil
    return execrc
  }
  return SQLITE_OK
}

/**
 * Insert a ``Threads`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_threads_insert(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The record to insert. Updated with the actual table values (e.g. assigned primary key).
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_threads_insert(_ db: OpaquePointer!, _ record: inout Threads)
  -> Int32
{
  let sql = ThreadsDB.useInsertReturning ? Threads.Schema.insertReturning : Threads.Schema.insert
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Threads.Schema.insertParameterIndices) {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      var sql = Threads.Schema.select
      sql.append(#" WHERE ROWID = last_insert_rowid()"#)
      var handle : OpaquePointer? = nil
      guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
            let statement = handle else { return sqlite3_errcode(db) }
      defer { sqlite3_finalize(statement) }
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        return SQLITE_OK
      }
      else if rc != SQLITE_ROW {
        return sqlite3_errcode(db)
      }
      record = Threads(statement, indices: Threads.Schema.selectColumnIndices)
      return SQLITE_OK
    }
    else if rc != SQLITE_ROW {
      return sqlite3_errcode(db)
    }
    record = Threads(statement, indices: Threads.Schema.selectColumnIndices)
    return SQLITE_OK
  }
}

/**
 * Update a ``Threads`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_threads_update(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Threads`` record to update.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_threads_update(_ db: OpaquePointer!, _ record: Threads) -> Int32
{
  let sql = Threads.Schema.update
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Threads.Schema.updateParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Delete a ``Threads`` record in the SQLite database.
 * 
 * This operates on a raw SQLite database handle (as returned by
 * `sqlite3_open`).
 * 
 * Example:
 * ```swift
 * let rc = sqlite3_threads_delete(db, record)
 * assert(rc == SQLITE_OK)
 * ```
 * 
 * - Parameters:
 *   - db: SQLite3 database handle.
 *   - record: The ``Threads`` record to delete.
 * - Returns: The SQLite error code (of `sqlite3_prepare/step`), e.g. `SQLITE_OK`.
 */
@inlinable
@discardableResult
public func sqlite3_threads_delete(_ db: OpaquePointer!, _ record: Threads) -> Int32
{
  let sql = Threads.Schema.delete
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return sqlite3_errcode(db) }
  defer { sqlite3_finalize(statement) }
  return record.bind(to: statement, indices: Threads.Schema.deleteParameterIndices) {
    let rc = sqlite3_step(statement)
    return rc != SQLITE_DONE && rc != SQLITE_ROW ? sqlite3_errcode(db) : SQLITE_OK
  }
}

/**
 * Fetch ``Threads`` records, filtering using a Swift closure.
 * 
 * This is fetching full ``Threads`` records from the passed in SQLite database
 * handle. The filtering is done within SQLite, but using a Swift closure
 * that can be passed in.
 * 
 * Within that closure other SQL queries can be done on separate connections,
 * but *not* within the same database handle that is being passed in (because
 * the closure is executed in the context of the query).
 * 
 * Sorting can be done using raw SQL (by passing in a `orderBy` parameter,
 * e.g. `orderBy: "name DESC"`),
 * or just in Swift (e.g. `fetch(in: db).sorted { $0.name > $1.name }`).
 * Since the matching is done in Swift anyways, the primary advantage of
 * doing it in SQL is that a `LIMIT` can be applied efficiently (i.e. w/o
 * walking and loading all rows).
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_threads_fetch(db) { record in
 *   record.name != "Duck"
 * }
 * 
 * let records = sqlite3_threads_fetch(db, orderBy: "name", limit: 5) {
 *   $0.firstname != nil
 * }
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Optional custom SQL yielding ``Threads`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 *   - filter: A Swift closure used for filtering, taking the``Threads`` record to be matched.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_threads_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil,
  filter: @escaping ( Threads ) -> Bool
) -> [ Threads ]?
{
  withUnsafePointer(to: filter) { ( closurePtr ) in
    guard Threads.Schema.registerSwiftMatcher(in: db, flags: SQLITE_UTF8, matcher: closurePtr) == SQLITE_OK else {
      return nil
    }
    defer {
      Threads.Schema.unregisterSwiftMatcher(in: db, flags: SQLITE_UTF8)
    }
    var sql = customSQL ?? Threads.Schema.matchSelect
    if let orderBySQL = orderBySQL {
      sql.append(" ORDER BY \(orderBySQL)")
    }
    if let limit = limit {
      sql.append(" LIMIT \(limit)")
    }
    var handle : OpaquePointer? = nil
    guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
          let statement = handle else { return nil }
    defer { sqlite3_finalize(statement) }
    let indices = customSQL != nil ? Threads.Schema.lookupColumnIndices(in: statement) : Threads.Schema.selectColumnIndices
    var records = [ Threads ]()
    while true {
      let rc = sqlite3_step(statement)
      if rc == SQLITE_DONE {
        break
      }
      else if rc != SQLITE_ROW {
        return nil
      }
      records.append(Threads(statement, indices: indices))
    }
    return records
  }
}

/**
 * Fetch ``Threads`` records using the base SQLite API.
 * 
 * If the function returns `nil`, the error can be found using the usual
 * `sqlite3_errcode` and companions.
 * 
 * Example:
 * ```swift
 * let records = sqlite3_threads_fetch(
 *   db, sql: #"SELECT * FROM threads"#
 * }
 * 
 * let records = sqlite3_threads_fetch(
 *   db, sql: #"SELECT * FROM threads"#,
 *   orderBy: "name", limit: 5
 * )
 * ```
 * 
 * - Parameters:
 *   - db: The SQLite database handle (as returned by `sqlite3_open`)
 *   - sql: Custom SQL yielding ``Threads`` records.
 *   - orderBySQL: If set, some SQL that is added as an `ORDER BY` clause (e.g. `name DESC`).
 *   - limit: An optional fetch limit.
 * - Returns: The records matching the query, or `nil` if there was an error.
 */
@inlinable
public func sqlite3_threads_fetch(
  _ db: OpaquePointer!,
  sql customSQL: String? = nil,
  orderBy orderBySQL: String? = nil,
  limit: Int? = nil
) -> [ Threads ]?
{
  var sql = customSQL ?? Threads.Schema.select
  if let orderBySQL = orderBySQL {
    sql.append(" ORDER BY \(orderBySQL)")
  }
  if let limit = limit {
    sql.append(" LIMIT \(limit)")
  }
  var handle : OpaquePointer? = nil
  guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK,
        let statement = handle else { return nil }
  defer { sqlite3_finalize(statement) }
  let indices = customSQL != nil ? Threads.Schema.lookupColumnIndices(in: statement) : Threads.Schema.selectColumnIndices
  var records = [ Threads ]()
  while true {
    let rc = sqlite3_step(statement)
    if rc == SQLITE_DONE {
      break
    }
    else if rc != SQLITE_ROW {
      return nil
    }
    records.append(Threads(statement, indices: indices))
  }
  return records
}

/**
 * A structure representing a SQLite database.
 * 
 * ### Database Schema
 * 
 * The schema captures the SQLite table/view catalog as safe Swift types.
 * 
 * #### Tables
 * 
 * - ``Threads`` (SQL: `threads`)
 * 
 * > Hint: Use [SQL Views](https://www.sqlite.org/lang_createview.html)
 * >       to create Swift types that represent common queries.
 * >       (E.g. joins between tables or fragments of table data.)
 * 
 * ### Examples
 * 
 * Perform record operations on ``Threads`` records:
 * ```swift
 * let records = try await db.threads.filter(orderBy: \.id) {
 *   $0.id != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.threads.find(2) // find by primaryKey
 *   
 *   record.id = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `threads` table:
 * ```swift
 * let values = try await db.select(from: \.threads, \.id) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Threads`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_threads_fetch(db, orderBy: "id", limit: 5) {
 *   $0.id != nil
 * }!
 * records[1].id = "Hunt"
 * sqlite3_threads_update(db, records[1])
 * 
 * sqlite3_threads_delete(db, records[0])
 * sqlite3_threads_insert(db, records[0]) // re-add
 * ```
 */
@dynamicMemberLookup
public struct ThreadsDB : SQLDatabase, SQLDatabaseAsyncChangeOperations, SQLCreationStatementsHolder {
  
  /**
   * Mappings of table/view Swift types to their "reference name".
   * 
   * The `RecordTypes` structure contains a variable for the Swift type
   * associated each table/view of the database. It maps the tables
   * "reference names" (e.g. ``threads``) to the
   * "record type" of the table (e.g. ``Threads``.self).
   */
  public struct RecordTypes : Swift.Sendable {
    
    /// Returns the Threads type information (SQL: `threads`).
    public let threads = Threads.self
  }
  
  /// Property based access to the ``RecordTypes-swift.struct``.
  public static let recordTypes = RecordTypes()
  
  #if swift(>=5.7)
  /// All RecordTypes defined in the database.
  public static let _allRecordTypes : [ any SQLRecord.Type ] = [ Threads.self ]
  #endif // swift(>=5.7)
  
  /// User version of the database (`PRAGMA user_version`).
  public static let userVersion = 0
  
  /// Whether `INSERT … RETURNING` should be used (requires SQLite 3.35.0+).
  public static let useInsertReturning = sqlite3_libversion_number() >= 3035000
  
  /// SQL that can be used to recreate the database structure.
  @inlinable
  public static var creationSQL : String {
    var sql = ""
    sql.append(Threads.Schema.create)
    return sql
  }
  
  public static func withOptCString<R>(
    _ s: String?,
    _ body: ( UnsafePointer<CChar>? ) throws -> R
  ) rethrows -> R
  {
    if let s = s { return try s.withCString(body) }
    else { return try body(nil) }
  }
  
  /// The `connectionHandler` is used to open SQLite database connections.
  public var connectionHandler : SQLConnectionHandler
  
  /**
   * Initialize ``ThreadsDB`` with a `URL`.
   * 
   * Configures the database with a simple connection pool opening the
   * specified `URL`.
   * And optional `readOnly` flag can be set (defaults to `false`).
   * 
   * Example:
   * ```swift
   * let db = ThreadsDB(url: ...)
   * 
   * // Write operations will raise an error.
   * let readOnly = ThreadsDB(
   *   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
   *   readOnly: true
   * )
   * ```
   * 
   * - Parameters:
   *   - url: A `URL` pointing to the database to be used.
   *   - readOnly: Whether the database should be opened readonly (default: `false`).
   */
  @inlinable
  public init(url: URL, readOnly: Bool = false)
  {
    self.connectionHandler = .simplePool(url: url, readOnly: readOnly)
  }
  
  /**
   * Initialize ``ThreadsDB`` w/ a `SQLConnectionHandler`.
   * 
   * `SQLConnectionHandler`'s are used to open SQLite database connections when
   * queries are run using the `Lighter` APIs.
   * The `SQLConnectionHandler` is a protocol and custom handlers
   * can be provided.
   * 
   * Example:
   * ```swift
   * let db = ThreadsDB(connectionHandler: .simplePool(
   *   url: Bundle.module.url(forResource: "samples", withExtension: "db"),
   *   readOnly: true,
   *   maxAge: 10,
   *   maximumPoolSizePerConfiguration: 4
   * ))
   * ```
   * 
   * - Parameters:
   *   - connectionHandler: The `SQLConnectionHandler` to use w/ the database.
   */
  @inlinable
  public init(connectionHandler: SQLConnectionHandler)
  {
    self.connectionHandler = connectionHandler
  }
}

/**
 * Record representing the `threads` SQL table.
 * 
 * Record types represent rows within tables&views in a SQLite database.
 * They are returned by the functions or queries/filters generated by
 * Enlighter.
 * 
 * ### Examples
 * 
 * Perform record operations on ``Threads`` records:
 * ```swift
 * let records = try await db.threads.filter(orderBy: \.id) {
 *   $0.id != nil
 * }
 * 
 * try await db.transaction { tx in
 *   var record = try tx.threads.find(2) // find by primaryKey
 *   
 *   record.id = "Hunt"
 *   try tx.update(record)
 * 
 *   let newRecord = try tx.insert(record)
 *   try tx.delete(newRecord)
 * }
 * ```
 * 
 * Perform column selects on the `threads` table:
 * ```swift
 * let values = try await db.select(from: \.threads, \.id) {
 *   $0.in([ 2, 3 ])
 * }
 * ```
 * 
 * Perform low level operations on ``Threads`` records:
 * ```swift
 * var db : OpaquePointer?
 * sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)
 * 
 * var records = sqlite3_threads_fetch(db, orderBy: "id", limit: 5) {
 *   $0.id != nil
 * }!
 * records[1].id = "Hunt"
 * sqlite3_threads_update(db, records[1])
 * 
 * sqlite3_threads_delete(db, records[0])
 * sqlite3_threads_insert(db, records[0]) // re-add
 * ```
 * 
 * ### SQL
 * 
 * The SQL used to create the table associated with the record:
 * ```sql
 * CREATE TABLE threads (
 *     id TEXT PRIMARY KEY,
 *     summary TEXT NOT NULL,
 *     updated_at TEXT NOT NULL,
 *     data_type TEXT NOT NULL,
 *     data BLOB NOT NULL
 * )
 * ```
 */
public struct Threads : Identifiable, SQLKeyedTableRecord, Codable, Sendable {
  
  /// Static SQL type information for the ``Threads`` record.
  public static let schema = Schema()
  
  /// Primary key `id` (`TEXT`), optional (default: `nil`).
  public var id : String?

	public var uuid: UUID? { id.flatMap(UUID.init(uuidString:)) }

  /// Column `summary` (`TEXT`), required.
  public var summary : String
  
  /// Column `updated_at` (`TEXT`), required.
  public var updatedAt : String
  
  /// Column `data_type` (`TEXT`), required.
  public var dataType : String
  
  /// Column `data` (`BLOB`), required.
  public var data : [ UInt8 ]

	public var dataAsData: Data { Data(data) }

  /**
   * Initialize a new ``Threads`` record.
   * 
   * - Parameters:
   *   - id: Primary key `id` (`TEXT`), optional (default: `nil`).
   *   - summary: Column `summary` (`TEXT`), required.
   *   - updatedAt: Column `updated_at` (`TEXT`), required.
   *   - dataType: Column `data_type` (`TEXT`), required.
   *   - data: Column `data` (`BLOB`), required.
   */
  @inlinable
  public init(
    id: String? = nil,
    summary: String,
    updatedAt: String,
    dataType: String,
    data: [ UInt8 ]
  )
  {
    self.id = id
    self.summary = summary
    self.updatedAt = updatedAt
    self.dataType = dataType
    self.data = data
  }
}

public extension Threads {
  
  /**
   * Static type information for the ``Threads`` record (`threads` SQL table).
   * 
   * This structure captures the static SQL information associated with the
   * record.
   * It is used for static type lookups and more.
   */
  struct Schema : SQLKeyedTableSchema, SQLSwiftMatchableSchema, SQLCreatableSchema {
    
    public typealias PropertyIndices = ( idx_id: Int32, idx_summary: Int32, idx_updatedAt: Int32, idx_dataType: Int32, idx_data: Int32 )
    public typealias RecordType = Threads
    public typealias MatchClosureType = ( Threads ) -> Bool
    
    /// The SQL table name associated with the ``Threads`` record.
    public static let externalName = "threads"
    
    /// The number of columns the `threads` table has.
    public static let columnCount : Int32 = 5
    
    /// Information on the records primary key (``Threads/id``).
    public static let primaryKeyColumn = MappedColumn<Threads, String?>(
      externalName: "id",
      defaultValue: nil,
      keyPath: \Threads.id
    )
    
    /// The SQL used to create the `threads` table.
    public static let create = 
      #"""
      CREATE TABLE threads (
          id TEXT PRIMARY KEY,
          summary TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          data_type TEXT NOT NULL,
          data BLOB NOT NULL
      );
      """#
    
    /// SQL to `SELECT` all columns of the `threads` table.
    public static let select = #"SELECT "id", "summary", "updated_at", "data_type", "data" FROM "threads""#
    
    /// SQL fragment representing all columns.
    public static let selectColumns = #""id", "summary", "updated_at", "data_type", "data""#
    
    /// Index positions of the properties in ``selectColumns``.
    public static let selectColumnIndices : PropertyIndices = ( 0, 1, 2, 3, 4 )
    
    /// SQL to `SELECT` all columns of the `threads` table using a Swift filter.
    public static let matchSelect = #"SELECT "id", "summary", "updated_at", "data_type", "data" FROM "threads" WHERE threads_swift_match("id", "summary", "updated_at", "data_type", "data") != 0"#
    
    /// SQL to `UPDATE` all columns of the `threads` table.
    public static let update = #"UPDATE "threads" SET "summary" = ?, "updated_at" = ?, "data_type" = ?, "data" = ? WHERE "id" = ?"#
    
    /// Property parameter indicies in the ``update`` SQL
    public static let updateParameterIndices : PropertyIndices = ( 5, 1, 2, 3, 4 )
    
    /// SQL to `INSERT` a record into the `threads` table.
    public static let insert = #"INSERT INTO "threads" ( "id", "summary", "updated_at", "data_type", "data" ) VALUES ( ?, ?, ?, ?, ? )"#
    
    /// SQL to `INSERT` a record into the `threads` table.
    public static let insertReturning = #"INSERT INTO "threads" ( "id", "summary", "updated_at", "data_type", "data" ) VALUES ( ?, ?, ?, ?, ? ) RETURNING "id", "summary", "updated_at", "data_type", "data""#
    
    /// Property parameter indicies in the ``insert`` SQL
    public static let insertParameterIndices : PropertyIndices = ( 1, 2, 3, 4, 5 )
    
    /// SQL to `DELETE` a record from the `threads` table.
    public static let delete = #"DELETE FROM "threads" WHERE "id" = ?"#
    
    /// Property parameter indicies in the ``delete`` SQL
    public static let deleteParameterIndices : PropertyIndices = ( 1, -1, -1, -1, -1 )
    
    /**
     * Lookup property indices by column name in a statement handle.
     * 
     * Properties are ordered in the schema and have a specific index
     * assigned.
     * E.g. if the record has two properties, `id` and `name`,
     * and the query was `SELECT age, threads_id FROM threads`,
     * this would return `( idx_id: 1, idx_name: -1 )`.
     * Because the `threads_id` is in the second position and `name`
     * isn't provided at all.
     * 
     * - Parameters:
     *   - statement: A raw SQLite3 prepared statement handle.
     * - Returns: The positions of the properties in the prepared statement.
     */
    @inlinable
    public static func lookupColumnIndices(`in` statement: OpaquePointer!)
      -> PropertyIndices
    {
      var indices : PropertyIndices = ( -1, -1, -1, -1, -1 )
      for i in 0..<sqlite3_column_count(statement) {
        let col = sqlite3_column_name(statement, i)
        if strcmp(col!, "id") == 0 {
          indices.idx_id = i
        }
        else if strcmp(col!, "summary") == 0 {
          indices.idx_summary = i
        }
        else if strcmp(col!, "updated_at") == 0 {
          indices.idx_updatedAt = i
        }
        else if strcmp(col!, "data_type") == 0 {
          indices.idx_dataType = i
        }
        else if strcmp(col!, "data") == 0 {
          indices.idx_data = i
        }
      }
      return indices
    }
    
    /**
     * Register the Swift matcher function for the ``Threads`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     *   - matcher: A pointer to the Swift closure used to filter the records.
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func registerSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8,
      matcher: UnsafeRawPointer
    ) -> Int32
    {
      func dispatch(
        _ context: OpaquePointer?,
        argc: Int32,
        argv: UnsafeMutablePointer<OpaquePointer?>!
      )
      {
        if let closureRawPtr = sqlite3_user_data(context) {
          let closurePtr = closureRawPtr.bindMemory(to: MatchClosureType.self, capacity: 1)
          let indices = Threads.Schema.selectColumnIndices
          let record = Threads(
            id: (indices.idx_id >= 0) && (indices.idx_id < argc) ? (sqlite3_value_text(argv[Int(indices.idx_id)]).flatMap(String.init(cString:))) : RecordType.schema.id.defaultValue,
            summary: ((indices.idx_summary >= 0) && (indices.idx_summary < argc) ? (sqlite3_value_text(argv[Int(indices.idx_summary)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.summary.defaultValue,
            updatedAt: ((indices.idx_updatedAt >= 0) && (indices.idx_updatedAt < argc) ? (sqlite3_value_text(argv[Int(indices.idx_updatedAt)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.updatedAt.defaultValue,
            dataType: ((indices.idx_dataType >= 0) && (indices.idx_dataType < argc) ? (sqlite3_value_text(argv[Int(indices.idx_dataType)]).flatMap(String.init(cString:))) : nil) ?? RecordType.schema.dataType.defaultValue,
            data: ((indices.idx_data >= 0) && (indices.idx_data < argc) ? (sqlite3_value_blob(argv[Int(indices.idx_data)]).flatMap({ [ UInt8 ](UnsafeRawBufferPointer(start: $0, count: Int(sqlite3_value_bytes(argv[Int(indices.idx_data)])))) })) : nil) ?? RecordType.schema.data.defaultValue
          )
          sqlite3_result_int(context, closurePtr.pointee(record) ? 1 : 0)
        }
        else {
          sqlite3_result_error(context, "Missing Swift matcher closure", -1)
        }
      }
      return sqlite3_create_function(
        unsafeDatabaseHandle,
        "threads_swift_match",
        Threads.Schema.columnCount,
        flags,
        UnsafeMutableRawPointer(mutating: matcher),
        dispatch,
        nil,
        nil
      )
    }
    
    /**
     * Unregister the Swift matcher function for the ``Threads`` record.
     * 
     * SQLite Swift matcher functions are used to process `filter` queries
     * and low-level matching w/o the Lighter library.
     * 
     * - Parameters:
     *   - unsafeDatabaseHandle: SQLite3 database handle.
     *   - flags: SQLite3 function registration flags, default: `SQLITE_UTF8`
     * - Returns: The result code of `sqlite3_create_function`, e.g. `SQLITE_OK`.
     */
    @inlinable
    @discardableResult
    public static func unregisterSwiftMatcher(
      `in` unsafeDatabaseHandle: OpaquePointer!,
      flags: Int32 = SQLITE_UTF8
    ) -> Int32
    {
      sqlite3_create_function(
        unsafeDatabaseHandle,
        "threads_swift_match",
        Threads.Schema.columnCount,
        flags,
        nil,
        nil,
        nil,
        nil
      )
    }
    
    /// Type information for property ``Threads/id`` (`id` column).
    public let id = MappedColumn<Threads, String?>(
      externalName: "id",
      defaultValue: nil,
      keyPath: \Threads.id
    )
    
    /// Type information for property ``Threads/summary`` (`summary` column).
    public let summary = MappedColumn<Threads, String>(
      externalName: "summary",
      defaultValue: "",
      keyPath: \Threads.summary
    )
    
    /// Type information for property ``Threads/updatedAt`` (`updated_at` column).
    public let updatedAt = MappedColumn<Threads, String>(
      externalName: "updated_at",
      defaultValue: "",
      keyPath: \Threads.updatedAt
    )
    
    /// Type information for property ``Threads/dataType`` (`data_type` column).
    public let dataType = MappedColumn<Threads, String>(
      externalName: "data_type",
      defaultValue: "",
      keyPath: \Threads.dataType
    )
    
    /// Type information for property ``Threads/data`` (`data` column).
    public let data = MappedColumn<Threads, [ UInt8 ]>(
      externalName: "data",
      defaultValue: [],
      keyPath: \Threads.data
    )
    
    #if swift(>=5.7)
    public var _allColumns : [ any SQLColumn ] { [ id, summary, updatedAt, dataType, data ] }
    #endif // swift(>=5.7)
    
    public init()
    {
    }
  }
  
  /**
   * Initialize a ``Threads`` record from a SQLite statement handle.
   * 
   * This initializer allows easy setup of a record structure from an
   * otherwise arbitrarily constructed SQLite prepared statement.
   * 
   * If no `indices` are specified, the `Schema/lookupColumnIndices`
   * function will be used to find the positions of the structure properties
   * based on their external name.
   * When looping, it is recommended to do the lookup once, and then
   * provide the `indices` to the initializer.
   * 
   * Required values that are missing in the statement are replaced with
   * their assigned default values, i.e. this can even be used to perform
   * partial selects w/ only a minor overhead (the extra space for a
   * record).
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(dbHandle, "SELECT * FROM threads", -1, &statement, nil)
   * while sqlite3_step(statement) == SQLITE_ROW {
   *   let record = Threads(statement)
   *   print("Fetched:", record)
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: Statement handle as returned by `sqlite3_prepare*` functions.
   *   - indices: Property bindings positions, defaults to `nil` (automatic lookup).
   */
  @inlinable
  init(_ statement: OpaquePointer!, indices: Schema.PropertyIndices? = nil)
  {
    let indices = indices ?? Self.Schema.lookupColumnIndices(in: statement)
    let argc = sqlite3_column_count(statement)
    self.init(
      id: (indices.idx_id >= 0) && (indices.idx_id < argc) ? (sqlite3_column_text(statement, indices.idx_id).flatMap(String.init(cString:))) : Self.schema.id.defaultValue,
      summary: ((indices.idx_summary >= 0) && (indices.idx_summary < argc) ? (sqlite3_column_text(statement, indices.idx_summary).flatMap(String.init(cString:))) : nil) ?? Self.schema.summary.defaultValue,
      updatedAt: ((indices.idx_updatedAt >= 0) && (indices.idx_updatedAt < argc) ? (sqlite3_column_text(statement, indices.idx_updatedAt).flatMap(String.init(cString:))) : nil) ?? Self.schema.updatedAt.defaultValue,
      dataType: ((indices.idx_dataType >= 0) && (indices.idx_dataType < argc) ? (sqlite3_column_text(statement, indices.idx_dataType).flatMap(String.init(cString:))) : nil) ?? Self.schema.dataType.defaultValue,
      data: ((indices.idx_data >= 0) && (indices.idx_data < argc) ? (sqlite3_column_blob(statement, indices.idx_data).flatMap({ [ UInt8 ](UnsafeRawBufferPointer(start: $0, count: Int(sqlite3_column_bytes(statement, indices.idx_data)))) })) : nil) ?? Self.schema.data.defaultValue
    )
  }
  
  /**
   * Bind all ``Threads`` properties to a prepared statement and call a closure.
   * 
   * *Important*: The bindings are only valid within the closure being executed!
   * 
   * Example:
   * ```swift
   * var statement : OpaquePointer?
   * sqlite3_prepare_v2(
   *   dbHandle,
   *   #"UPDATE "threads" SET "summary" = ?, "updated_at" = ?, "data_type" = ?, "data" = ? WHERE "id" = ?"#,
   *   -1, &statement, nil
   * )
   * 
   * let record = Threads(id: "Hello", summary: "World", updatedAt: "Duck", dataType: "Donald", data: ...)
   * let ok = record.bind(to: statement, indices: ( 5, 1, 2, 3, 4 )) {
   *   sqlite3_step(statement) == SQLITE_DONE
   * }
   * sqlite3_finalize(statement)
   * ```
   * 
   * - Parameters:
   *   - statement: A SQLite3 statement handle as returned by the `sqlite3_prepare*` functions.
   *   - indices: The parameter positions for the bindings.
   *   - execute: Closure executed with bindings applied, bindings _only_ valid within the call!
   * - Returns: Returns the result of the closure that is passed in.
   */
  @inlinable
  @discardableResult
  func bind<R>(
    to statement: OpaquePointer!,
    indices: Schema.PropertyIndices,
    then execute: () throws -> R
  ) rethrows -> R
  {
    return try ThreadsDB.withOptCString(id) { ( s ) in
      if indices.idx_id >= 0 {
        sqlite3_bind_text(statement, indices.idx_id, s, -1, nil)
      }
      return try summary.withCString() { ( s ) in
        if indices.idx_summary >= 0 {
          sqlite3_bind_text(statement, indices.idx_summary, s, -1, nil)
        }
        return try updatedAt.withCString() { ( s ) in
          if indices.idx_updatedAt >= 0 {
            sqlite3_bind_text(statement, indices.idx_updatedAt, s, -1, nil)
          }
          return try dataType.withCString() { ( s ) in
            if indices.idx_dataType >= 0 {
              sqlite3_bind_text(statement, indices.idx_dataType, s, -1, nil)
            }
            return try data.withUnsafeBytes() { ( rbp ) in
              if indices.idx_data >= 0 {
                sqlite3_bind_blob(statement, indices.idx_data, rbp.baseAddress, Int32(rbp.count), nil)
              }
              return try execute()
            }
          }
        }
      }
    }
  }
}
