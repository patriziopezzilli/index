import Foundation
import Combine

class DatabaseService: ObservableObject {
    @Published var activeWorkspaces: [WorkspaceTab] = []
    @Published var selectedWorkspaceIndex: Int = 0
    
    @Published var queryHistory: [QueryHistory] = []
    @Published var savedQueries: [SavedQuery] = []
    @Published var savedConnections: [DatabaseConnection] = []

    private var cancellables = Set<AnyCancellable>()
    private let keychain = KeychainService.shared

    init() {
        loadHistory()
        loadSavedQueries()
        loadConnections()
    }

    var currentWorkspace: WorkspaceTab? {
        guard !activeWorkspaces.isEmpty, selectedWorkspaceIndex < activeWorkspaces.count else { return nil }
        return activeWorkspaces[selectedWorkspaceIndex]
    }

    var isConnected: Bool {
        !activeWorkspaces.isEmpty
    }

    func connect(to connection: DatabaseConnection) async throws {
        // If already connected to this connection ID, just switch to it
        if let index = activeWorkspaces.firstIndex(where: { $0.connection.id == connection.id }) {
            await MainActor.run {
                self.selectedWorkspaceIndex = index
            }
            return
        }

        // Create appropriate driver
        let driver = DatabaseDriverFactory.createDriver(for: connection)

        // Connect
        try await driver.connect()

        // Update lastUsed for saved connection
        if let index = savedConnections.firstIndex(where: { $0.id == connection.id }) {
            await MainActor.run {
                self.savedConnections[index].lastUsed = Date()
                self.saveConnections()
            }
        }

        // Create new workspace tab
        let newWorkspace = WorkspaceTab(connection: connection, driver: driver)

        // Update state
        await MainActor.run {
            self.activeWorkspaces.append(newWorkspace)
            self.selectedWorkspaceIndex = self.activeWorkspaces.count - 1
        }
    }

    func disconnect(workspace: WorkspaceTab? = nil) {
        let wsToClose = workspace ?? currentWorkspace
        guard let ws = wsToClose else { return }
        
        try? ws.driver.disconnect()
        
        if let index = activeWorkspaces.firstIndex(where: { $0.id == ws.id }) {
            activeWorkspaces.remove(at: index)
            if selectedWorkspaceIndex >= activeWorkspaces.count && !activeWorkspaces.isEmpty {
                selectedWorkspaceIndex = activeWorkspaces.count - 1
            }
        }
    }

    func disconnectAll() {
        for ws in activeWorkspaces {
            try? ws.driver.disconnect()
        }
        activeWorkspaces.removeAll()
        selectedWorkspaceIndex = 0
    }

    func executeQuery(_ query: String, in workspace: WorkspaceTab? = nil) async -> QueryResult {
        guard let ws = workspace ?? currentWorkspace else {
            return QueryResult(columns: [], rows: [], rowsAffected: nil, executionTime: 0, error: "No active workspace select")
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Track transaction state
        let isTransactionCommand = trimmedQuery.hasPrefix("begin") ||
                                   trimmedQuery.hasPrefix("commit") ||
                                   trimmedQuery.hasPrefix("rollback")

        do {
            let result = try await ws.driver.execute(query)
            await addToHistory(query: query, executionTime: result.executionTime, success: true)

            // Update transaction state based on query
            await MainActor.run {
                if trimmedQuery.hasPrefix("begin") {
                    ws.transactionState = .active
                    ws.transactionQueryCount = 0
                } else if trimmedQuery.hasPrefix("commit") || trimmedQuery.hasPrefix("rollback") {
                    ws.transactionState = .none
                    ws.transactionQueryCount = 0
                } else if ws.isInTransaction && !isTransactionCommand {
                    ws.transactionQueryCount += 1
                }
            }

            return result
        } catch {
            await addToHistory(query: query, executionTime: 0, success: false)
            return QueryResult(columns: [], rows: [], rowsAffected: nil, executionTime: 0, error: error.localizedDescription)
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

    func loadSchema(for workspace: WorkspaceTab? = nil) async {
        guard let ws = workspace ?? currentWorkspace else { return }

        do {
            let schema = try await ws.driver.loadSchema()
            await MainActor.run {
                ws.schema = schema
            }
        } catch {
            print("Failed to load schema: \(error)")
        }
    }

    func fetchTableData(tableName: String, page: Int = 1, pageSize: Int = 100, in workspace: WorkspaceTab? = nil) async -> QueryResult {
        guard let ws = workspace ?? currentWorkspace else {
            return QueryResult(columns: [], rows: [], rowsAffected: nil, executionTime: 0, error: "No active workspace")
        }

        do {
            var result = try await ws.driver.fetchTableData(tableName: tableName, page: page, pageSize: pageSize)
            result.tableName = tableName
            result.primaryKeyColumn = ws.schema?.tables.first(where: { $0.name == tableName })?.columns.first(where: { $0.isPrimaryKey })?.name
            return result
        } catch {
            return QueryResult(columns: [], rows: [], rowsAffected: nil, executionTime: 0, error: error.localizedDescription)
        }
    }

    func updateCell(tableName: String, columnName: String, newValue: String, primaryKeyColumn: String, primaryKeyValue: String, in workspace: WorkspaceTab? = nil) async throws {
        guard let ws = workspace ?? currentWorkspace else {
            throw DatabaseDriverError.notConnected
        }
        
        try await ws.driver.updateCell(
            tableName: tableName,
            columnName: columnName,
            newValue: newValue,
            primaryKeyColumn: primaryKeyColumn,
            primaryKeyValue: primaryKeyValue
        )
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

    // MARK: - Connection Management

    func saveConnection(_ connection: DatabaseConnection) {
        if !connection.password.isEmpty {
            try? keychain.saveConnectionPassword(connection.password, connectionId: connection.id)
        }

        var conn = connection
        if let index = savedConnections.firstIndex(where: { $0.id == connection.id }) {
            savedConnections[index] = conn
        } else {
            savedConnections.append(conn)
        }

        saveConnections()
    }

    func deleteConnection(_ connection: DatabaseConnection) {
        try? keychain.deleteConnectionPassword(connectionId: connection.id)
        savedConnections.removeAll { $0.id == connection.id }
        saveConnections()
    }

    func toggleFavorite(_ connection: DatabaseConnection) {
        if let index = savedConnections.firstIndex(where: { $0.id == connection.id }) {
            savedConnections[index].isFavorite.toggle()
            saveConnections()
        }
    }

    func getConnectionWithPassword(id: UUID) -> DatabaseConnection? {
        guard let storable = savedConnections.first(where: { $0.id == id })?.safeForStorage else {
            return nil
        }
        let password = keychain.getConnectionPassword(connectionId: id) ?? ""
        return DatabaseConnection.fromStorable(storable, password: password)
    }

    private func loadConnections() {
        if let data = UserDefaults.standard.data(forKey: "savedConnections"),
           let decoded = try? JSONDecoder().decode([StorableConnection].self, from: data) {
            savedConnections = decoded.map { storable in
                let password = keychain.getConnectionPassword(connectionId: storable.id) ?? ""
                return DatabaseConnection.fromStorable(storable, password: password)
            }
        }
    }

    private func saveConnections() {
        let storableConnections = savedConnections.map { $0.safeForStorage }
        if let encoded = try? JSONEncoder().encode(storableConnections) {
            UserDefaults.standard.set(encoded, forKey: "savedConnections")
        }
    }

    var recentConnections: [DatabaseConnection] {
        savedConnections
            .filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? Date.distantPast) > ($1.lastUsed ?? Date.distantPast) }
            .prefix(5)
            .map { $0 }
    }

    var favoriteConnections: [DatabaseConnection] {
        savedConnections.filter { $0.isFavorite }
    }
}
