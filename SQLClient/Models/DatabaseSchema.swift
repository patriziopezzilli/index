import Foundation

struct DatabaseSchema: Identifiable, Codable {
    let id = UUID()
    let name: String
    let tables: [TableSchema]
}

struct TableSchema: Identifiable, Codable {
    let id = UUID()
    let name: String
    let columns: [ColumnSchema]
    let rowCount: Int
}

struct ColumnSchema: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: String
    let nullable: Bool
    let isPrimaryKey: Bool
    let defaultValue: String?

    var typeIcon: String {
        switch type.lowercased() {
        case let t where t.contains("int"):
            return "number"
        case let t where t.contains("varchar"), let t where t.contains("text"), let t where t.contains("char"):
            return "textformat"
        case let t where t.contains("date"), let t where t.contains("time"):
            return "calendar"
        case let t where t.contains("bool"):
            return "checkmark.circle"
        case let t where t.contains("float"), let t where t.contains("decimal"), let t where t.contains("numeric"):
            return "number.circle"
        default:
            return "questionmark.circle"
        }
    }
}
