import Foundation

struct QueryResult: Identifiable {
    let id = UUID()
    var columns: [String]
    var rows: [[String]]
    var rowsAffected: Int?
    var executionTime: TimeInterval
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
