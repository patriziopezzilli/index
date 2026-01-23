import Foundation
import Combine
import CoreGraphics

enum TransactionState: String {
    case none = "none"
    case active = "active"
    case pending = "pending"
}

class WorkspaceTab: Identifiable, ObservableObject {
    let id = UUID()
    let connection: DatabaseConnection
    let driver: DatabaseDriver

    @Published var schema: DatabaseSchema?
    @Published var subTabs: [WorkspaceSubTab] = []
    @Published var selectedSubTabId: UUID?
    @Published var queryToRun: String?
    @Published var tablePositions: [String: CGPoint] = [:]
    @Published var transactionState: TransactionState = .none
    @Published var transactionQueryCount: Int = 0

    init(connection: DatabaseConnection, driver: DatabaseDriver) {
        self.connection = connection
        self.driver = driver

        // Add initial SQL Editor tab
        let defaultTab = WorkspaceSubTab(name: "SQL Worksheet", type: .editor)
        self.subTabs = [defaultTab]
        self.selectedSubTabId = defaultTab.id
    }

    var isInTransaction: Bool {
        transactionState == .active
    }
    
    var currentSubTab: WorkspaceSubTab? {
        subTabs.first(where: { $0.id == selectedSubTabId })
    }
    
    func openTable(_ tableName: String) {
        if let existing = subTabs.first(where: { $0.tableContext == tableName }) {
            selectedSubTabId = existing.id
        } else {
            let newTab = WorkspaceSubTab(name: tableName, type: .table, tableContext: tableName)
            subTabs.append(newTab)
            selectedSubTabId = newTab.id
        }
    }

    func openERModel() {
        if let existing = subTabs.first(where: { $0.type == .erModel }) {
            selectedSubTabId = existing.id
        } else {
            let newTab = WorkspaceSubTab(name: "ER Model", type: .erModel)
            subTabs.append(newTab)
            selectedSubTabId = newTab.id
        }
    }
    
    func closeSubTab(_ tabId: UUID) {
        guard subTabs.count > 0 else { return }
        
        if let index = subTabs.firstIndex(where: { $0.id == tabId }) {
            subTabs.remove(at: index)
            if selectedSubTabId == tabId {
                selectedSubTabId = subTabs.last?.id
            }
        }
        
        if subTabs.isEmpty {
            let defaultTab = WorkspaceSubTab(name: "SQL Worksheet", type: .editor)
            subTabs = [defaultTab]
            selectedSubTabId = defaultTab.id
        }
    }

    func generateBackupSQL() -> String? {
        guard let schema = schema else { return nil }
        return ImportExportService.shared.generateFullSchemaExport(schema: schema)
    }
}
