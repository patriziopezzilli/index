import Foundation

struct SavedQuery: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var query: String
    var category: String
    let createdAt: Date
    var lastModified: Date

    init(id: UUID = UUID(), name: String, query: String, category: String = "Uncategorized") {
        self.id = id
        self.name = name
        self.query = query
        self.category = category
        self.createdAt = Date()
        self.lastModified = Date()
    }

    var categoryIcon: String {
        switch category.lowercased() {
        case "select":
            return "magnifyingglass"
        case "insert":
            return "plus.circle"
        case "update":
            return "pencil.circle"
        case "delete":
            return "trash.circle"
        case "create":
            return "hammer"
        case "drop":
            return "xmark.circle"
        default:
            return "folder"
        }
    }

    var categoryColor: String {
        switch category.lowercased() {
        case "select":
            return "blue"
        case "insert":
            return "green"
        case "update":
            return "orange"
        case "delete":
            return "red"
        case "create":
            return "purple"
        case "drop":
            return "red"
        default:
            return "gray"
        }
    }
}
