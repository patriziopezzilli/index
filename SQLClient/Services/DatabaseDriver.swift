import Foundation

// MARK: - Database Driver Protocol

protocol DatabaseDriver {
    var connection: DatabaseConnection { get }
    var isConnected: Bool { get }

    func connect() async throws
    func disconnect() throws
    func execute(_ query: String) async throws -> QueryResult
    func loadSchema() async throws -> DatabaseSchema
}

// MARK: - Driver Errors

enum DatabaseDriverError: LocalizedError {
    case notConnected
    case connectionFailed(String)
    case queryFailed(String)
    case invalidQuery
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to database"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .invalidQuery:
            return "Invalid query"
        case .unsupportedOperation:
            return "Operation not supported for this database type"
        }
    }
}

// MARK: - Driver Factory

class DatabaseDriverFactory {
    static func createDriver(for connection: DatabaseConnection) -> DatabaseDriver {
        switch connection.type {
        case .sqlite:
            return SQLiteDriver(connection: connection)
        case .postgresql, .mysql, .sqlserver:
            return MockDriver(connection: connection)
        }
    }
}

// MARK: - Mock Driver (for unsupported databases)

class MockDriver: DatabaseDriver {
    let connection: DatabaseConnection
    private(set) var isConnected = false

    init(connection: DatabaseConnection) {
        self.connection = connection
    }

    func connect() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        isConnected = true
    }

    func disconnect() throws {
        isConnected = false
    }

    func execute(_ query: String) async throws -> QueryResult {
        try await Task.sleep(nanoseconds: 300_000_000)

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.hasPrefix("select") {
            return QueryResult(
                columns: ["id", "name", "value"],
                rows: [
                    ["1", "Mock Data", "123"],
                    ["2", "Test Entry", "456"]
                ],
                rowsAffected: nil,
                executionTime: 0.3
            )
        } else if trimmed.hasPrefix("insert") || trimmed.hasPrefix("update") || trimmed.hasPrefix("delete") {
            return QueryResult(
                columns: [],
                rows: [],
                rowsAffected: 1,
                executionTime: 0.3
            )
        } else {
            return QueryResult(
                columns: [],
                rows: [],
                rowsAffected: 0,
                executionTime: 0.3
            )
        }
    }

    func loadSchema() async throws -> DatabaseSchema {
        return DatabaseSchema(
            name: connection.database,
            tables: [
                TableSchema(
                    name: "mock_table",
                    columns: [
                        ColumnSchema(name: "id", type: "INTEGER", nullable: false, isPrimaryKey: true, defaultValue: nil),
                        ColumnSchema(name: "name", type: "TEXT", nullable: true, isPrimaryKey: false, defaultValue: nil)
                    ],
                    rowCount: 0
                )
            ]
        )
    }
}
