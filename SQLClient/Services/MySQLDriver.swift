import Foundation
import MySQLNIO
import NIOCore
import NIOPosix
import Logging

class MySQLDriver: DatabaseDriver {
    let connection: DatabaseConnection
    private(set) var isConnected = false

    private var mysqlConnection: MySQLConnection?
    private let eventLoopGroup: EventLoopGroup
    private let logger: Logger
    private var sshTunnel: SSHTunnelService?

    init(connection: DatabaseConnection) {
        self.connection = connection
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        var logger = Logger(label: "mysql-driver")
        logger.logLevel = .warning
        self.logger = logger

        // Initialize SSH tunnel if needed
        if connection.sshConfig.enabled {
            self.sshTunnel = SSHTunnelService(
                sshConfig: connection.sshConfig,
                remoteHost: connection.host,
                remotePort: connection.port
            )
        }
    }

    deinit {
        try? disconnect()
        try? eventLoopGroup.syncShutdownGracefully()
    }

    // MARK: - Connection Management

    func connect() async throws {
        // Establish SSH tunnel if needed
        var actualHost = connection.host
        var actualPort = connection.port

        if let tunnel = sshTunnel {
            do {
                let localPort = try await tunnel.connect()
                actualHost = "127.0.0.1"
                actualPort = localPort
            } catch {
                throw DatabaseDriverError.connectionFailed("SSH tunnel failed: \(error.localizedDescription)")
            }
        }

        do {
            let address = try SocketAddress(ipAddress: actualHost, port: actualPort)
            mysqlConnection = try await MySQLConnection.connect(
                to: address,
                username: connection.username,
                database: connection.database,
                password: connection.password,
                tlsConfiguration: nil,
                logger: logger,
                on: eventLoopGroup.next()
            ).get()
            isConnected = true
        } catch {
            // Clean up tunnel if connection fails
            sshTunnel?.disconnect()
            throw DatabaseDriverError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() throws {
        guard let conn = mysqlConnection else { return }

        Task {
            _ = try? await conn.close().get()
        }

        mysqlConnection = nil
        isConnected = false

        // Disconnect SSH tunnel
        sshTunnel?.disconnect()
    }

    // MARK: - Query Execution

    func execute(_ query: String) async throws -> QueryResult {
        guard isConnected, let conn = mysqlConnection else {
            throw DatabaseDriverError.notConnected
        }

        let startTime = Date()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if trimmedQuery.lowercased().hasPrefix("select") ||
               trimmedQuery.lowercased().hasPrefix("show") ||
               trimmedQuery.lowercased().hasPrefix("describe") ||
               trimmedQuery.lowercased().hasPrefix("explain") {
                return try await executeSelectQuery(trimmedQuery, conn: conn, startTime: startTime)
            } else {
                return try await executeModifyQuery(trimmedQuery, conn: conn, startTime: startTime)
            }
        } catch {
            throw DatabaseDriverError.queryFailed(error.localizedDescription)
        }
    }

    private func executeSelectQuery(_ query: String, conn: MySQLConnection, startTime: Date) async throws -> QueryResult {
        let rows = try await conn.query(query).get()

        var columns: [String] = []
        var resultRows: [[String]] = []

        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df
        }()

        for row in rows {
            if columns.isEmpty {
                columns = row.columnDefinitions.map { $0.name }
            }

            var rowData: [String] = []
            for i in 0..<row.columnDefinitions.count {
                let columnName = row.columnDefinitions[i].name
                let column = row.column(columnName)
                
                if let value = column?.int {
                    rowData.append(String(value))
                } else if let value = column?.double {
                    rowData.append(String(value))
                } else if let value = column?.float {
                    rowData.append(String(value))
                } else if let value = column?.date {
                    rowData.append(dateFormatter.string(from: value))
                } else if let value = column?.bool {
                    rowData.append(value ? "1" : "0")
                } else if let value = column?.string {
                    rowData.append(value)
                } else if column == nil {
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

    private func executeModifyQuery(_ query: String, conn: MySQLConnection, startTime: Date) async throws -> QueryResult {
        let rows = try await conn.query(query).get()
        let executionTime = Date().timeIntervalSince(startTime)

        return QueryResult(
            columns: [],
            rows: [],
            rowsAffected: rows.count > 0 ? rows.count : 1,
            executionTime: executionTime
        )
    }

    // MARK: - Schema Loading

    func loadSchema() async throws -> DatabaseSchema {
        guard isConnected, let conn = mysqlConnection else {
            throw DatabaseDriverError.notConnected
        }

        var schema = DatabaseSchema(name: connection.database)

        // 1. Get Tables
        let tableRows = try await conn.query("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'").get()
        for row in tableRows {
            if let tableName = row.column(row.columnDefinitions[0].name)?.string {
                if let tableSchema = try? await loadTableSchema(tableName, conn: conn) {
                    schema.tables.append(tableSchema)
                }
            }
        }

        // 2. Get Views
        let viewRows = try await conn.query("SHOW FULL TABLES WHERE Table_type = 'VIEW'").get()
        for row in viewRows {
            if let name = row.column(row.columnDefinitions[0].name)?.string {
                schema.views.append(SchemaObject(name: name, type: "VIEW", definition: nil))
            }
        }

        // 3. Get Functions & Procedures
        let procedureRows = try await conn.query("SHOW PROCEDURE STATUS WHERE Db = '\(connection.database)'").get()
        for row in procedureRows {
            if let name = row.column("Name")?.string {
                schema.procedures.append(SchemaObject(name: name, type: "PROCEDURE", definition: nil))
            }
        }

        let functionRows = try await conn.query("SHOW FUNCTION STATUS WHERE Db = '\(connection.database)'").get()
        for row in functionRows {
            if let name = row.column("Name")?.string {
                schema.functions.append(SchemaObject(name: name, type: "FUNCTION", definition: nil))
            }
        }

        return schema
    }

    private func loadTableSchema(_ tableName: String, conn: MySQLConnection) async throws -> TableSchema {
        var columns: [ColumnSchema] = []
        var foreignKeys: [ForeignKeySchema] = []

        // 1. Get foreign key information
        let fkQuery = """
            SELECT
                COLUMN_NAME,
                REFERENCED_TABLE_NAME,
                REFERENCED_COLUMN_NAME
            FROM
                INFORMATION_SCHEMA.KEY_COLUMN_USAGE
            WHERE
                TABLE_SCHEMA = '\(connection.database)'
                AND TABLE_NAME = '\(tableName)'
                AND REFERENCED_TABLE_NAME IS NOT NULL;
            """
        
        let fkRows = try await conn.query(fkQuery).get()
        for row in fkRows {
            let colName = row.column("COLUMN_NAME")?.string ?? ""
            let targetTable = row.column("REFERENCED_TABLE_NAME")?.string ?? ""
            let targetCol = row.column("REFERENCED_COLUMN_NAME")?.string ?? ""
            
            foreignKeys.append(ForeignKeySchema(columnName: colName, targetTable: targetTable, targetColumn: targetCol))
        }

        // 2. Get column information using DESCRIBE
        let rows = try await conn.query("DESCRIBE `\(tableName)`").get()

        for row in rows {
            let name = row.column(row.columnDefinitions[0].name)?.string ?? ""
            let type = row.column(row.columnDefinitions[1].name)?.string ?? ""
            let nullable = row.column(row.columnDefinitions[2].name)?.string == "YES"
            let key = row.column(row.columnDefinitions[3].name)?.string ?? ""
            let defaultValue = row.column(row.columnDefinitions[4].name)?.string

            columns.append(ColumnSchema(
                name: name,
                type: type.uppercased(),
                nullable: nullable,
                isPrimaryKey: key == "PRI",
                defaultValue: defaultValue
            ))
        }

        // 3. Get row count
        var rowCount = 0
        let countRows = try await conn.query("SELECT COUNT(*) as cnt FROM `\(tableName)`").get()
        if let firstRow = countRows.first,
           let count = firstRow.column(firstRow.columnDefinitions[0].name)?.int {
            rowCount = count
        }

        return TableSchema(name: tableName, columns: columns, foreignKeys: foreignKeys, rowCount: rowCount)
    }

    func fetchTableData(tableName: String, page: Int, pageSize: Int) async throws -> QueryResult {
        guard isConnected, let conn = mysqlConnection else {
            throw DatabaseDriverError.notConnected
        }

        let startTime = Date()
        let offset = (page - 1) * pageSize

        // 1. Get total count
        let countRows = try await conn.query("SELECT COUNT(*) as cnt FROM `\(tableName)`").get()
        let totalRows = countRows.first?.column("cnt")?.int ?? 0

        // 2. Get paginated data
        let rows = try await conn.query("SELECT * FROM `\(tableName)` LIMIT \(pageSize) OFFSET \(offset)").get()

        var columns: [String] = []
        var resultRows: [[String]] = []

        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df
        }()

        for row in rows {
            if columns.isEmpty {
                columns = row.columnDefinitions.map { $0.name }
            }

            var rowData: [String] = []
            for i in 0..<row.columnDefinitions.count {
                let columnName = row.columnDefinitions[i].name
                let column = row.column(columnName)
                
                if let value = column?.int {
                    rowData.append(String(value))
                } else if let value = column?.double {
                    rowData.append(String(value))
                } else if let value = column?.float {
                    rowData.append(String(value))
                } else if let value = column?.date {
                    rowData.append(dateFormatter.string(from: value))
                } else if let value = column?.bool {
                    rowData.append(value ? "1" : "0")
                } else if let value = column?.string {
                    rowData.append(value)
                } else if column == nil {
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
        guard isConnected, let conn = mysqlConnection else {
            throw DatabaseDriverError.notConnected
        }
        
        let query = "UPDATE `\(tableName)` SET `\(columnName)` = '\(newValue.replacingOccurrences(of: "'", with: "\\'"))' WHERE `\(primaryKeyColumn)` = '\(primaryKeyValue.replacingOccurrences(of: "'", with: "\\'"))'"
        _ = try await conn.query(query).get()
    }
}
