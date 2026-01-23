import Foundation

enum WorkspaceSubTabType: String, Codable {
    case table
    case editor
    case erModel
}

struct WorkspaceSubTab: Identifiable, Codable {
    let id: UUID
    var name: String
    let type: WorkspaceSubTabType
    var tableContext: String? // Name of the table if type == .table
    var queryTabId: UUID? // ID of the QueryTab if type == .editor
    
    init(id: UUID = UUID(), name: String, type: WorkspaceSubTabType, tableContext: String? = nil, queryTabId: UUID? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.tableContext = tableContext
        self.queryTabId = queryTabId
    }
}
