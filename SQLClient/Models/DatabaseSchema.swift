import Foundation

struct DatabaseSchema: Identifiable, Codable {
    let id = UUID()
    let name: String
    var tables: [TableSchema] = []
    var views: [SchemaObject] = []
    var sequences: [SchemaObject] = []
    var functions: [SchemaObject] = []
    var procedures: [SchemaObject] = []
    var indexes: [SchemaObject] = []

    static let empty = DatabaseSchema(name: "")
}

struct SchemaObject: Identifiable, Codable {
    let id = UUID()
    let name: String
    let type: String // e.g., "VIEW", "SEQUENCE", "FUNCTION"
    let definition: String?
}

struct TableSchema: Identifiable, Codable {
    let id = UUID()
    let name: String
    let columns: [ColumnSchema]
    var foreignKeys: [ForeignKeySchema] = []
    let rowCount: Int
}

struct ForeignKeySchema: Identifiable, Codable {
    let id = UUID()
    let columnName: String
    let targetTable: String
    let targetColumn: String
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
