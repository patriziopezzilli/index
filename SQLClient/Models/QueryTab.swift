import Foundation

class QueryTab: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var query: String
    @Published var result: QueryResult?
    @Published var isExecuting: Bool = false

    init(id: UUID = UUID(), name: String = "New Query", query: String = "") {
        self.id = id
        self.name = name
        self.query = query
        self.result = nil
    }

    func updateName(from query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            name = "New Query"
        } else {
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? ""
            let preview = String(firstLine.prefix(20))
            name = preview.isEmpty ? "New Query" : preview + (firstLine.count > 20 ? "..." : "")
        }
    }
}
