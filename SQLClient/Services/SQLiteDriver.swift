import Foundation
import SQLite3

class SQLiteDriver: DatabaseDriver {
    let connection: DatabaseConnection
    private(set) var isConnected = false
    private var db: OpaquePointer?

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    deinit {
        try? disconnect()
    }

    // MARK: - Connection Management

    func connect() async throws {
        let path = getDatabasePath()

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseDriverError.connectionFailed(errorMessage)
        }

        isConnected = true
    }

    func disconnect() throws {
        guard isConnected, let db = db else { return }

        if sqlite3_close(db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseDriverError.connectionFailed("Failed to close: \(errorMessage)")
        }

        self.db = nil
        isConnected = false
    }

    // MARK: - Query Execution

    func execute(_ query: String) async throws -> QueryResult {
        guard isConnected, let db = db else {
            throw DatabaseDriverError.notConnected
        }

        let startTime = Date()

        // Split multi-query if needed (execute only first for now)
        let queries = splitQueries(query)
        guard let firstQuery = queries.first else {
            throw DatabaseDriverError.invalidQuery
        }

        let trimmedQuery = firstQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a SELECT query
        if trimmedQuery.lowercased().hasPrefix("select") || trimmedQuery.lowercased().hasPrefix("pragma") {
            return try await executeSelectQuery(trimmedQuery, db: db, startTime: startTime)
        } else {
            return try await executeModifyQuery(trimmedQuery, db: db, startTime: startTime)
        }
    }

    // MARK: - Schema Loading

    func loadSchema() async throws -> DatabaseSchema {
        guard isConnected, let db = db else {
            throw DatabaseDriverError.notConnected
        }

        var tables: [TableSchema] = []

        // Get all tables
        let tablesQuery = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name;"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, tablesQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let cString = sqlite3_column_text(statement, 0) {
                    let tableName = String(cString: cString)
                    if let tableSchema = try? await loadTableSchema(tableName, db: db) {
                        tables.append(tableSchema)
                    }
                }
            }
        }
        sqlite3_finalize(statement)

        return DatabaseSchema(name: connection.database, tables: tables)
    }

    // MARK: - Private Helpers

    private func getDatabasePath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbName = connection.database.isEmpty ? "default.db" : connection.database
        return documentsPath.appendingPathComponent(dbName).path
    }

    private func splitQueries(_ query: String) -> [String] {
        return query
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func executeSelectQuery(_ query: String, db: OpaquePointer, startTime: Date) async throws -> QueryResult {
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw DatabaseDriverError.queryFailed(errorMessage)
        }

        defer { sqlite3_finalize(statement) }

        // Get column names
        let columnCount = sqlite3_column_count(statement)
        var columns: [String] = []
        for i in 0..<columnCount {
            if let cString = sqlite3_column_name(statement, i) {
                columns.append(String(cString: cString))
            }
        }

        // Get rows
        var rows: [[String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String] = []
            for i in 0..<columnCount {
                if let cString = sqlite3_column_text(statement, i) {
                    row.append(String(cString: cString))
                } else {
                    row.append("NULL")
                }
            }
            rows.append(row)
        }

        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: columns,
            rows: rows,
            rowsAffected: nil,
            executionTime: executionTime
        )
    }

    private func executeModifyQuery(_ query: String, db: OpaquePointer, startTime: Date) async throws -> QueryResult {
        var errorMessage: UnsafeMutablePointer<CChar>?

        guard sqlite3_exec(db, query, nil, nil, &errorMessage) == SQLITE_OK else {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseDriverError.queryFailed(error)
        }

        let changes = Int(sqlite3_changes(db))
        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: [],
            rows: [],
            rowsAffected: changes,
            executionTime: executionTime
        )
    }

    private func loadTableSchema(_ tableName: String, db: OpaquePointer) async throws -> TableSchema {
        var columns: [ColumnSchema] = []
        var foreignKeys: [ForeignKeySchema] = []

        // 1. Get foreign key information
        let fkQuery = "PRAGMA foreign_key_list('\(tableName)');"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, fkQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                // column 3 is 'from' (column name), column 2 is 'table' (target table), column 4 is 'to' (target column)
                if let fromCol = sqlite3_column_text(statement, 3),
                   let toTable = sqlite3_column_text(statement, 2),
                   let toCol = sqlite3_column_text(statement, 4) {
                    
                    foreignKeys.append(ForeignKeySchema(
                        columnName: String(cString: fromCol),
                        targetTable: String(cString: toTable),
                        targetColumn: String(cString: toCol)
                    ))
                }
            }
        }
        sqlite3_finalize(statement)

        // 2. Get table info
        let tableInfoQuery = "PRAGMA table_info('\(tableName)');"

        if sqlite3_prepare_v2(db, tableInfoQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 1))
                let type = String(cString: sqlite3_column_text(statement, 2))
                let notNull = sqlite3_column_int(statement, 3) != 0
                let defaultValue = sqlite3_column_text(statement, 4).map { String(cString: $0) }
                let isPrimaryKey = sqlite3_column_int(statement, 5) != 0

                columns.append(ColumnSchema(
                    name: name,
                    type: type,
                    nullable: !notNull,
                    isPrimaryKey: isPrimaryKey,
                    defaultValue: defaultValue
                ))
            }
        }
        sqlite3_finalize(statement)

        // 3. Get row count
        let countQuery = "SELECT COUNT(*) FROM \(tableName);"
        var rowCount = 0

        if sqlite3_prepare_v2(db, countQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                rowCount = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        return TableSchema(name: tableName, columns: columns, foreignKeys: foreignKeys, rowCount: rowCount)
    }

    func fetchTableData(tableName: String, page: Int, pageSize: Int) async throws -> QueryResult {
        guard isConnected, let db = db else {
            throw DatabaseDriverError.notConnected
        }

        let startTime = Date()
        let offset = (page - 1) * pageSize

        // 1. Get total count
        let countQuery = "SELECT COUNT(*) FROM \(tableName);"
        var totalRows = 0
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, countQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                totalRows = Int(sqlite3_column_int(statement, 0))
            }
        }
        sqlite3_finalize(statement)

        // 2. Get paginated data
        let dataQuery = "SELECT * FROM \(tableName) LIMIT \(pageSize) OFFSET \(offset);"
        let result = try await executeSelectQuery(dataQuery, db: db, startTime: startTime)

        return QueryResult(
            columns: result.columns,
            rows: result.rows,
            totalRows: totalRows,
            page: page,
            pageSize: pageSize,
            rowsAffected: nil,
            executionTime: result.executionTime
        )
    }

    func updateCell(tableName: String, columnName: String, newValue: String, primaryKeyColumn: String, primaryKeyValue: String) async throws {
        guard isConnected, let db = db else {
            throw DatabaseDriverError.notConnected
        }
        
        let query = "UPDATE \(tableName) SET \(columnName) = '\(newValue.replacingOccurrences(of: "'", with: "''"))' WHERE \(primaryKeyColumn) = '\(primaryKeyValue.replacingOccurrences(of: "'", with: "''"))';"
        var errorMessage: UnsafeMutablePointer<CChar>?
        
        if sqlite3_exec(db, query, nil, nil, &errorMessage) != SQLITE_OK {
            let error = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseDriverError.queryFailed(error)
        }
    }
}
