import Foundation
import Combine

class DatabaseService: ObservableObject {
    @Published var currentConnection: DatabaseConnection?
    @Published var isConnected = false
    @Published var queryHistory: [QueryHistory] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadHistory()
    }

    func connect(to connection: DatabaseConnection) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            self.currentConnection = connection
            self.isConnected = true
        }
    }

    func disconnect() {
        currentConnection = nil
        isConnected = false
    }

    func executeQuery(_ query: String) async -> QueryResult {
        let startTime = Date()

        try? await Task.sleep(nanoseconds: 500_000_000)

        let executionTime = Date().timeIntervalSince(startTime)

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmedQuery.hasPrefix("select") {
            let columns = ["id", "name", "email", "created_at"]
            let rows = [
                ["1", "John Doe", "john@example.com", "2024-01-15"],
                ["2", "Jane Smith", "jane@example.com", "2024-01-16"],
                ["3", "Bob Johnson", "bob@example.com", "2024-01-17"]
            ]

            await addToHistory(query: query, executionTime: executionTime, success: true)

            return QueryResult(
                columns: columns,
                rows: rows,
                rowsAffected: nil,
                executionTime: executionTime
            )
        } else if trimmedQuery.hasPrefix("insert") || trimmedQuery.hasPrefix("update") || trimmedQuery.hasPrefix("delete") {
            await addToHistory(query: query, executionTime: executionTime, success: true)

            return QueryResult(
                columns: [],
                rows: [],
                rowsAffected: Int.random(in: 1...10),
                executionTime: executionTime
            )
        } else {
            await addToHistory(query: query, executionTime: executionTime, success: true)

            return QueryResult(
                columns: [],
                rows: [],
                rowsAffected: 0,
                executionTime: executionTime
            )
        }
    }

    func testConnection(_ connection: DatabaseConnection) async -> Bool {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return true
    }

    private func addToHistory(query: String, executionTime: TimeInterval, success: Bool) async {
        let historyItem = QueryHistory(query: query, executionTime: executionTime, success: success)
        await MainActor.run {
            queryHistory.insert(historyItem, at: 0)
            if queryHistory.count > 100 {
                queryHistory.removeLast()
            }
            saveHistory()
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "queryHistory"),
           let decoded = try? JSONDecoder().decode([QueryHistory].self, from: data) {
            queryHistory = decoded
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(queryHistory) {
            UserDefaults.standard.set(encoded, forKey: "queryHistory")
        }
    }
}
