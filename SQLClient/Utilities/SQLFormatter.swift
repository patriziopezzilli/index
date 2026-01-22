import Foundation

class SQLFormatter {
    private static let majorKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "ORDER",
        "HAVING", "LIMIT", "UNION", "CASE", "WHEN", "THEN", "ELSE", "END"
    ]

    private static let minorKeywords: Set<String> = [
        "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE", "IS", "NULL", "AS", "BY", "ASC", "DESC"
    ]

    static func format(_ query: String) -> String {
        var formatted = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Add newlines before major keywords
        for keyword in majorKeywords {
            let patterns = [
                "\\b\(keyword)\\b",
                "\(keyword.lowercased())"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(formatted.startIndex..., in: formatted)
                    let template = "\n\(keyword.uppercased())"
                    formatted = regex.stringByReplacingMatches(
                        in: formatted,
                        options: [],
                        range: range,
                        withTemplate: template
                    )
                }
            }
        }

        // Uppercase all keywords
        for keyword in majorKeywords.union(minorKeywords) {
            formatted = formatted.replacingOccurrences(
                of: "\\b\(keyword)\\b",
                with: keyword.uppercased(),
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Clean up whitespace
        formatted = formatted
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        // Add indentation
        var indented = ""
        var indentLevel = 0

        for line in formatted.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Decrease indent for certain keywords
            if trimmed.hasPrefix("FROM") || trimmed.hasPrefix("WHERE") || trimmed.hasPrefix("GROUP") || trimmed.hasPrefix("ORDER") || trimmed.hasPrefix("HAVING") {
                indentLevel = 1
            } else if trimmed.hasPrefix("SELECT") || trimmed.hasPrefix("INSERT") || trimmed.hasPrefix("UPDATE") || trimmed.hasPrefix("DELETE") {
                indentLevel = 0
            }

            let indent = String(repeating: "  ", count: indentLevel)
            indented += indent + trimmed + "\n"

            // Increase indent for certain keywords
            if trimmed.hasPrefix("SELECT") {
                indentLevel = 1
            }
        }

        // Final cleanup
        return indented
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func splitQueries(_ text: String) -> [String] {
        return text
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
