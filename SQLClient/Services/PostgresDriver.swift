import Foundation
import PostgresNIO
import NIOCore
import NIOPosix
import Logging

class PostgresDriver: DatabaseDriver {
    let connection: DatabaseConnection
    private(set) var isConnected = false

    private var postgresConnection: PostgresConnection?
    private let eventLoopGroup: EventLoopGroup
    private let logger: Logger

    init(connection: DatabaseConnection) {
        self.connection = connection
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        var logger = Logger(label: "postgres-driver")
        logger.logLevel = .warning
        self.logger = logger
    }

    deinit {
        try? disconnect()
        try? eventLoopGroup.syncShutdownGracefully()
    }

    // MARK: - Connection Management

    func connect() async throws {
        let config = PostgresConnection.Configuration(
            host: connection.host,
            port: connection.port,
            username: connection.username,
            password: connection.password,
            database: connection.database,
            tls: .disable
        )

        do {
            postgresConnection = try await PostgresConnection.connect(
                on: eventLoopGroup.next(),
                configuration: config,
                id: 1,
                logger: logger
            )
            isConnected = true
        } catch {
            throw DatabaseDriverError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() throws {
        guard let conn = postgresConnection else { return }

        Task {
            try? await conn.close()
        }

        postgresConnection = nil
        isConnected = false
    }

    // MARK: - Query Execution

    func execute(_ query: String) async throws -> QueryResult {
        guard isConnected, let conn = postgresConnection else {
            throw DatabaseDriverError.notConnected
        }

        let startTime = Date()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if trimmedQuery.lowercased().hasPrefix("select") ||
               trimmedQuery.lowercased().hasPrefix("show") ||
               trimmedQuery.lowercased().hasPrefix("explain") {
                return try await executeSelectQuery(trimmedQuery, conn: conn, startTime: startTime)
            } else {
                return try await executeModifyQuery(trimmedQuery, conn: conn, startTime: startTime)
            }
        } catch {
            throw DatabaseDriverError.queryFailed(error.localizedDescription)
        }
    }

    private func executeSelectQuery(_ query: String, conn: PostgresConnection, startTime: Date) async throws -> QueryResult {
        let rows = try await conn.query(PostgresQuery(stringLiteral: query), logger: logger)

        var columns: [String] = []
        var resultRows: [[String]] = []
        var isFirstRow = true

        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df
        }()

        for try await row in rows {
            if isFirstRow {
                columns = row.map { $0.columnName }
                isFirstRow = false
            }

            var rowData: [String] = []
            for column in row {
                if let value = try? column.decode(Int.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Int64.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Double.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Float.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Date.self) {
                    rowData.append(dateFormatter.string(from: value))
                } else if let value = try? column.decode(Bool.self) {
                    rowData.append(value ? "true" : "false")
                } else if let value = try? column.decode(String.self) {
                    rowData.append(value)
                } else if column.bytes == nil {
                    rowData.append("NULL")
                } else {
                    rowData.append("(binary)")
                }
            }
            resultRows.append(rowData)
        }

        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: columns,
            rows: resultRows,
            rowsAffected: nil,
            executionTime: executionTime
        )
    }

    private func executeModifyQuery(_ query: String, conn: PostgresConnection, startTime: Date) async throws -> QueryResult {
        let result = try await conn.query(PostgresQuery(stringLiteral: query), logger: logger)

        var rowCount = 0
        for try await _ in result {
            rowCount += 1
        }

        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: [],
            rows: [],
            rowsAffected: rowCount > 0 ? rowCount : 1,
            executionTime: executionTime
        )
    }

    // MARK: - Schema Loading

    func loadSchema() async throws -> DatabaseSchema {
        guard isConnected, let conn = postgresConnection else {
            throw DatabaseDriverError.notConnected
        }

        var schema = DatabaseSchema(name: connection.database)

        // 1. Get Tables
        let tablesQuery = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE' ORDER BY table_name;"
        let tableRows = try await conn.query(PostgresQuery(stringLiteral: tablesQuery), logger: logger)
        var tableNames: [String] = []
        for try await row in tableRows {
            if let tableName = try? row.first?.decode(String.self) {
                tableNames.append(tableName)
            }
        }
        for tableName in tableNames {
            if let tableSchema = try? await loadTableSchema(tableName, conn: conn) {
                schema.tables.append(tableSchema)
            }
        }

        // 2. Get Views
        let viewsQuery = "SELECT table_name FROM information_schema.views WHERE table_schema = 'public' ORDER BY table_name;"
        let viewRows = try await conn.query(PostgresQuery(stringLiteral: viewsQuery), logger: logger)
        for try await row in viewRows {
            if let name = try? row.first?.decode(String.self) {
                schema.views.append(SchemaObject(name: name, type: "VIEW", definition: nil))
            }
        }

        // 3. Get Sequences
        let sequencesQuery = "SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public' ORDER BY sequence_name;"
        let sequenceRows = try await conn.query(PostgresQuery(stringLiteral: sequencesQuery), logger: logger)
        for try await row in sequenceRows {
            if let name = try? row.first?.decode(String.self) {
                schema.sequences.append(SchemaObject(name: name, type: "SEQUENCE", definition: nil))
            }
        }

        // 4. Get Functions
        let functionsQuery = "SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'FUNCTION' ORDER BY routine_name;"
        let funcRows = try await conn.query(PostgresQuery(stringLiteral: functionsQuery), logger: logger)
        for try await row in funcRows {
            if let name = try? row.first?.decode(String.self) {
                schema.functions.append(SchemaObject(name: name, type: "FUNCTION", definition: nil))
            }
        }

        return schema
    }

    private func loadTableSchema(_ tableName: String, conn: PostgresConnection) async throws -> TableSchema {
        var columns: [ColumnSchema] = []
        var foreignKeys: [ForeignKeySchema] = []

        // 1. Get foreign key information
        let fkQuery = """
            SELECT
                kcu.column_name,
                ccu.table_name AS foreign_table_name,
                ccu.column_name AS foreign_column_name
            FROM
                information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name
                  AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                  ON ccu.constraint_name = tc.constraint_name
                  AND ccu.table_schema = tc.table_schema
            WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name = '\(tableName)' AND tc.table_schema = 'public';
            """
        
        if let fkRows = try? await conn.query(PostgresQuery(stringLiteral: fkQuery), logger: logger) {
            for try await row in fkRows {
                let cells = Array(row)
                if cells.count >= 3 {
                    let colName = (try? cells[0].decode(String.self)) ?? ""
                    let targetTable = (try? cells[1].decode(String.self)) ?? ""
                    let targetCol = (try? cells[2].decode(String.self)) ?? ""
                    
                    foreignKeys.append(ForeignKeySchema(columnName: colName, targetTable: targetTable, targetColumn: targetCol))
                }
            }
        }

        // 2. Get column information
        let columnsQuery = """
            SELECT
                column_name,
                data_type,
                is_nullable,
                column_default,
                (SELECT COUNT(*) > 0 FROM information_schema.key_column_usage kcu
                 JOIN information_schema.table_constraints tc ON kcu.constraint_name = tc.constraint_name
                 WHERE tc.constraint_type = 'PRIMARY KEY'
                 AND kcu.table_name = c.table_name
                 AND kcu.column_name = c.column_name) as is_primary_key
            FROM information_schema.columns c
            WHERE table_schema = 'public'
            AND table_name = '\(tableName)'
            ORDER BY ordinal_position;
            """

        let rows = try await conn.query(PostgresQuery(stringLiteral: columnsQuery), logger: logger)

        for try await row in rows {
            let cells = Array(row)
            let name = (try? cells[0].decode(String.self)) ?? ""
            let type = (try? cells[1].decode(String.self)) ?? ""
            let nullable = (try? cells[2].decode(String.self)) == "YES"
            let defaultValue = try? cells[3].decode(String.self)
            let isPrimaryKey = (try? cells[4].decode(Bool.self)) ?? false

            columns.append(ColumnSchema(
                name: name,
                type: type.uppercased(),
                nullable: nullable,
                isPrimaryKey: isPrimaryKey,
                defaultValue: defaultValue
            ))
        }

        // 3. Get row count
        let countQuery = "SELECT COUNT(*) FROM \"\(tableName)\";"
        var rowCount = 0

        let countRows = try await conn.query(PostgresQuery(stringLiteral: countQuery), logger: logger)
        for try await row in countRows {
            rowCount = (try? row.first?.decode(Int.self)) ?? 0
        }

        return TableSchema(name: tableName, columns: columns, foreignKeys: foreignKeys, rowCount: rowCount)
    }

    func fetchTableData(tableName: String, page: Int, pageSize: Int) async throws -> QueryResult {
        guard isConnected, let conn = postgresConnection else {
            throw DatabaseDriverError.notConnected
        }

        let startTime = Date()
        let offset = (page - 1) * pageSize

        // 1. Get total count
        let countQuery = "SELECT COUNT(*) FROM \"\(tableName)\";"
        var totalRows = 0
        let countRows = try await conn.query(PostgresQuery(stringLiteral: countQuery), logger: logger)
        for try await row in countRows {
            totalRows = (try? row.first?.decode(Int.self)) ?? 0
        }

        // 2. Get paginated data
        let dataQuery = "SELECT * FROM \"\(tableName)\" LIMIT \(pageSize) OFFSET \(offset);"
        let rows = try await conn.query(PostgresQuery(stringLiteral: dataQuery), logger: logger)

        var columns: [String] = []
        var resultRows: [[String]] = []
        var isFirstRow = true

        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df
        }()

        for try await row in rows {
            if isFirstRow {
                columns = row.map { $0.columnName }
                isFirstRow = false
            }

            var rowData: [String] = []
            for column in row {
                if let value = try? column.decode(Int.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Int64.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Double.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Float.self) {
                    rowData.append(String(value))
                } else if let value = try? column.decode(Date.self) {
                    rowData.append(dateFormatter.string(from: value))
                } else if let value = try? column.decode(Bool.self) {
                    rowData.append(value ? "true" : "false")
                } else if let value = try? column.decode(String.self) {
                    rowData.append(value)
                } else if column.bytes == nil {
                    rowData.append("NULL")
                } else {
                    rowData.append("(binary)")
                }
            }
            resultRows.append(rowData)
        }

        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: columns,
            rows: resultRows,
            totalRows: totalRows,
            page: page,
            pageSize: pageSize,
            rowsAffected: nil,
            executionTime: executionTime
        )
    }

    func updateCell(tableName: String, columnName: String, newValue: String, primaryKeyColumn: String, primaryKeyValue: String) async throws {
        guard isConnected, let conn = postgresConnection else {
            throw DatabaseDriverError.notConnected
        }
        
        // Use string interpolation with escaping for now. In a production app, we would use parameterized queries.
        let query = "UPDATE \"\(tableName)\" SET \"\(columnName)\" = '\(newValue.replacingOccurrences(of: "'", with: "''"))' WHERE \"\(primaryKeyColumn)\" = '\(primaryKeyValue.replacingOccurrences(of: "'", with: "''"))'"
        _ = try await conn.query(PostgresQuery(stringLiteral: query), logger: logger)
    }
}
