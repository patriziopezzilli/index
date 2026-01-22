import Foundation
import Combine

class DatabaseService: ObservableObject {
    @Published var currentConnection: DatabaseConnection?
    @Published var isConnected = false
    @Published var queryHistory: [QueryHistory] = []
    @Published var savedQueries: [SavedQuery] = []
    @Published var currentSchema: DatabaseSchema?

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadHistory()
        loadSavedQueries()
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

    // MARK: - Schema Browser

    func loadSchema() async {
        guard isConnected else { return }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Mock schema data
        let mockSchema = DatabaseSchema(
            name: currentConnection?.database ?? "Database",
            tables: [
                TableSchema(
                    name: "users",
                    columns: [
                        ColumnSchema(name: "id", type: "INTEGER", nullable: false, isPrimaryKey: true, defaultValue: nil),
                        ColumnSchema(name: "name", type: "VARCHAR(255)", nullable: false, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "email", type: "VARCHAR(255)", nullable: false, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "created_at", type: "TIMESTAMP", nullable: false, isPrimaryKey: false, defaultValue: "CURRENT_TIMESTAMP")
                    ],
                    rowCount: 1542
                ),
                TableSchema(
                    name: "orders",
                    columns: [
                        ColumnSchema(name: "id", type: "INTEGER", nullable: false, isPrimaryKey: true, defaultValue: nil),
                        ColumnSchema(name: "user_id", type: "INTEGER", nullable: false, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "total", type: "DECIMAL(10,2)", nullable: false, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "status", type: "VARCHAR(50)", nullable: false, isPrimaryKey: false, defaultValue: "'pending'"),
                        ColumnSchema(name: "created_at", type: "TIMESTAMP", nullable: false, isPrimaryKey: false, defaultValue: "CURRENT_TIMESTAMP")
                    ],
                    rowCount: 8934
                ),
                TableSchema(
                    name: "products",
                    columns: [
                        ColumnSchema(name: "id", type: "INTEGER", nullable: false, isPrimaryKey: true, defaultValue: nil),
                        ColumnSchema(name: "name", type: "VARCHAR(255)", nullable: false, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "description", type: "TEXT", nullable: true, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "price", type: "DECIMAL(10,2)", nullable: false, isPrimaryKey: false, defaultValue: nil),
                        ColumnSchema(name: "stock", type: "INTEGER", nullable: false, isPrimaryKey: false, defaultValue: "0"),
                        ColumnSchema(name: "is_active", type: "BOOLEAN", nullable: false, isPrimaryKey: false, defaultValue: "true")
                    ],
                    rowCount: 256
                )
            ]
        )

        await MainActor.run {
            self.currentSchema = mockSchema
        }
    }

    // MARK: - Saved Queries

    func saveQuery(name: String, query: String, category: String) {
        let savedQuery = SavedQuery(name: name, query: query, category: category)
        savedQueries.append(savedQuery)
        saveSavedQueries()
    }

    func updateQuery(_ query: SavedQuery) {
        if let index = savedQueries.firstIndex(where: { $0.id == query.id }) {
            savedQueries[index] = query
            saveSavedQueries()
        }
    }

    func deleteQuery(_ query: SavedQuery) {
        savedQueries.removeAll { $0.id == query.id }
        saveSavedQueries()
    }

    private func loadSavedQueries() {
        if let data = UserDefaults.standard.data(forKey: "savedQueries"),
           let decoded = try? JSONDecoder().decode([SavedQuery].self, from: data) {
            savedQueries = decoded
        }
    }

    private func saveSavedQueries() {
        if let encoded = try? JSONEncoder().encode(savedQueries) {
            UserDefaults.standard.set(encoded, forKey: "savedQueries")
        }
    }

    var categories: [String] {
        let allCategories = savedQueries.map { $0.category }
        return Array(Set(allCategories)).sorted()
    }
}
