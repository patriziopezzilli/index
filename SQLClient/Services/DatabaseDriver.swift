import Foundation

// MARK: - Database Driver Protocol

protocol DatabaseDriver {
    var connection: DatabaseConnection { get }
    var isConnected: Bool { get }

    func connect() async throws
    func disconnect() throws
    func execute(_ query: String) async throws -> QueryResult
    func loadSchema() async throws -> DatabaseSchema
    func fetchTableData(tableName: String, page: Int, pageSize: Int) async throws -> QueryResult
    func updateCell(tableName: String, columnName: String, newValue: String, primaryKeyColumn: String, primaryKeyValue: String) async throws
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
        case .postgresql:
            return PostgresDriver(connection: connection)
        case .mysql:
            return MySQLDriver(connection: connection)
        }
    }
}
