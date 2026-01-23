import Foundation

class SQLAutocomplete {
    struct Suggestion: Identifiable {
        let id = UUID()
        let text: String
        let type: SuggestionType
        let description: String?

        var detail: String? { description }

        enum SuggestionType {
            case keyword
            case table
            case column
            case function
        }

    }

    private static let sqlKeywords = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "JOIN", "LEFT", "RIGHT",
        "INNER", "OUTER", "ON", "AS", "AND", "OR", "NOT", "IN", "BETWEEN",
        "LIKE", "IS", "NULL", "ORDER BY", "GROUP BY", "HAVING", "LIMIT",
        "OFFSET", "UNION", "DISTINCT", "COUNT", "SUM", "AVG", "MIN", "MAX"
    ]

    private static let sqlFunctions = [
        "COUNT(*)", "SUM()", "AVG()", "MIN()", "MAX()", "ROUND()", "UPPER()",
        "LOWER()", "LENGTH()", "TRIM()", "DATE()", "NOW()", "COALESCE()"
    ]

    static func getSuggestions(
        for query: String,
        cursorPosition: Int,
        tables: [String] = [],
        columns: [String] = []
    ) -> [Suggestion] {
        let beforeCursor = String(query.prefix(cursorPosition))
        let words = beforeCursor.components(separatedBy: .whitespacesAndNewlines)
        guard let lastWord = words.last?.uppercased(), !lastWord.isEmpty else {
            return []
        }

        var suggestions: [Suggestion] = []

        // Add matching keywords
        for keyword in sqlKeywords {
            if keyword.hasPrefix(lastWord) {
                suggestions.append(Suggestion(
                    text: keyword,
                    type: .keyword,
                    description: "SQL Keyword"
                ))
            }
        }

        // Add matching functions
        for function in sqlFunctions {
            if function.uppercased().hasPrefix(lastWord) {
                suggestions.append(Suggestion(
                    text: function,
                    type: .function,
                    description: "SQL Function"
                ))
            }
        }

        // Add matching tables
        for table in tables {
            if table.uppercased().hasPrefix(lastWord) {
                suggestions.append(Suggestion(
                    text: table,
                    type: .table,
                    description: "Table"
                ))
            }
        }

        // Add matching columns
        for column in columns {
            if column.uppercased().hasPrefix(lastWord) {
                suggestions.append(Suggestion(
                    text: column,
                    type: .column,
                    description: "Column"
                ))
            }
        }

        return Array(suggestions.prefix(10)) // Limit to 10 suggestions
    }

    // New simplified method for use with current word and schema
    static func getSuggestions(
        for query: String,
        currentWord: String,
        schema: DatabaseSchema?
    ) -> [Suggestion] {
        let word = currentWord.uppercased()
        guard !word.isEmpty else { return [] }

        var suggestions: [Suggestion] = []

        // Add matching keywords
        for keyword in sqlKeywords {
            if keyword.hasPrefix(word) {
                suggestions.append(Suggestion(
                    text: keyword,
                    type: .keyword,
                    description: "Keyword"
                ))
            }
        }

        // Add matching functions
        for function in sqlFunctions {
            if function.uppercased().hasPrefix(word) {
                suggestions.append(Suggestion(
                    text: function,
                    type: .function,
                    description: "Function"
                ))
            }
        }

        // Add matching tables from schema
        if let schema = schema {
            for table in schema.tables {
                if table.name.uppercased().hasPrefix(word) {
                    suggestions.append(Suggestion(
                        text: table.name,
                        type: .table,
                        description: "\(table.columns.count) columns"
                    ))
                }

                // Add matching columns
                for column in table.columns {
                    if column.name.uppercased().hasPrefix(word) {
                        suggestions.append(Suggestion(
                            text: column.name,
                            type: .column,
                            description: "\(table.name).\(column.type)"
                        ))
                    }
                }
            }
        }

        return Array(suggestions.prefix(10))
    }

    static func getCommonSnippets() -> [Suggestion] {
        return [
            Suggestion(
                text: "SELECT * FROM ",
                type: .keyword,
                description: "Select all from table"
            ),
            Suggestion(
                text: "INSERT INTO table_name (columns) VALUES (values)",
                type: .keyword,
                description: "Insert new row"
            ),
            Suggestion(
                text: "UPDATE table_name SET column = value WHERE condition",
                type: .keyword,
                description: "Update rows"
            ),
            Suggestion(
                text: "DELETE FROM table_name WHERE condition",
                type: .keyword,
                description: "Delete rows"
            ),
            Suggestion(
                text: "CREATE TABLE table_name (id INTEGER PRIMARY KEY, name TEXT)",
                type: .keyword,
                description: "Create new table"
            )
        ]
    }
}
