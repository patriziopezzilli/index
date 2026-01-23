import Foundation

struct QueryResult: Identifiable {
    let id = UUID()
    var columns: [String]
    var rows: [[String]]
    var totalRows: Int?
    var page: Int = 1
    var pageSize: Int = 100
    var rowsAffected: Int?
    var executionTime: TimeInterval
    var tableName: String?
    var primaryKeyColumn: String?
    var error: String?

    var isSuccess: Bool {
        error == nil
    }

    static var empty: QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: nil, executionTime: 0)
    }
}

struct QueryHistory: Identifiable, Codable {
    var id = UUID()
    var query: String
    var timestamp: Date
    var executionTime: TimeInterval
    var success: Bool

    init(query: String, executionTime: TimeInterval, success: Bool) {
        self.query = query
        self.timestamp = Date()
        self.executionTime = executionTime
        self.success = success
    }
}
