import Foundation
import Combine

class DatabaseService: ObservableObject {
    @Published var currentConnection: DatabaseConnection?
    @Published var isConnected = false
    @Published var queryHistory: [QueryHistory] = []
    @Published var savedQueries: [SavedQuery] = []
    @Published var currentSchema: DatabaseSchema?

    private var cancellables = Set<AnyCancellable>()
    private var currentDriver: DatabaseDriver?

    init() {
        loadHistory()
        loadSavedQueries()
    }

    func connect(to connection: DatabaseConnection) async throws {
        // Create appropriate driver
        let driver = DatabaseDriverFactory.createDriver(for: connection)

        // Connect
        try await driver.connect()

        // Update state
        await MainActor.run {
            self.currentDriver = driver
            self.currentConnection = connection
            self.isConnected = true
            self.currentSchema = nil // Reset schema on new connection
        }
    }

    func disconnect() {
        try? currentDriver?.disconnect()
        currentDriver = nil
        currentConnection = nil
        isConnected = false
        currentSchema = nil
    }

    func executeQuery(_ query: String) async -> QueryResult {
        guard let driver = currentDriver else {
            await addToHistory(query: query, executionTime: 0, success: false)
            return QueryResult(
                columns: [],
                rows: [],
                rowsAffected: nil,
                executionTime: 0,
                error: "Not connected to database"
            )
        }

        do {
            let result = try await driver.execute(query)
            await addToHistory(query: query, executionTime: result.executionTime, success: true)
            return result
        } catch {
            await addToHistory(query: query, executionTime: 0, success: false)
            return QueryResult(
                columns: [],
                rows: [],
                rowsAffected: nil,
                executionTime: 0,
                error: error.localizedDescription
            )
        }
    }

    func testConnection(_ connection: DatabaseConnection) async -> Bool {
        let driver = DatabaseDriverFactory.createDriver(for: connection)

        do {
            try await driver.connect()
            try driver.disconnect()
            return true
        } catch {
            return false
        }
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
        guard isConnected, let driver = currentDriver else { return }

        do {
            let schema = try await driver.loadSchema()
            await MainActor.run {
                self.currentSchema = schema
            }
        } catch {
            print("Failed to load schema: \(error)")
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
