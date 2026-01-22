import SwiftUI

class SQLSyntaxHighlighter {
    // SQL Keywords
    private static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
        "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "INDEX", "VIEW", "PROCEDURE",
        "FUNCTION", "TRIGGER", "DATABASE", "SCHEMA", "JOIN", "LEFT", "RIGHT", "INNER",
        "OUTER", "ON", "AS", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE", "IS", "NULL",
        "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT",
        "COUNT", "SUM", "AVG", "MIN", "MAX", "CASE", "WHEN", "THEN", "ELSE", "END",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "UNIQUE", "DEFAULT",
        "CHECK", "CASCADE", "AUTO_INCREMENT", "AUTOINCREMENT", "INTEGER", "TEXT",
        "VARCHAR", "CHAR", "DATE", "DATETIME", "TIMESTAMP", "BOOLEAN", "DECIMAL", "REAL"
    ]

    // SQL Functions
    private static let functions: Set<String> = [
        "COUNT", "SUM", "AVG", "MIN", "MAX", "ROUND", "UPPER", "LOWER", "LENGTH",
        "SUBSTR", "SUBSTRING", "TRIM", "LTRIM", "RTRIM", "COALESCE", "IFNULL",
        "CAST", "CONVERT", "NOW", "DATE", "TIME", "YEAR", "MONTH", "DAY"
    ]

    static func highlight(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)

        // Color scheme
        let keywordColor = Color.blue
        let functionColor = Color.purple
        let stringColor = Color.green
        let numberColor = Color.orange
        let commentColor = Color.gray
        let defaultColor = Color.white

        // Default color
        attributed.foregroundColor = defaultColor

        // Highlight keywords
        highlightPattern(
            in: &attributed,
            pattern: "\\b(" + keywords.joined(separator: "|") + ")\\b",
            color: keywordColor,
            options: [.caseInsensitive]
        )

        // Highlight functions
        highlightPattern(
            in: &attributed,
            pattern: "\\b(" + functions.joined(separator: "|") + ")\\s*\\(",
            color: functionColor,
            options: [.caseInsensitive]
        )

        // Highlight strings (single and double quotes)
        highlightPattern(
            in: &attributed,
            pattern: "'[^']*'|\"[^\"]*\"",
            color: stringColor
        )

        // Highlight numbers
        highlightPattern(
            in: &attributed,
            pattern: "\\b\\d+(\\.\\d+)?\\b",
            color: numberColor
        )

        // Highlight comments
        highlightPattern(
            in: &attributed,
            pattern: "--[^\n]*",
            color: commentColor
        )

        highlightPattern(
            in: &attributed,
            pattern: "/\\*[\\s\\S]*?\\*/",
            color: commentColor
        )

        return attributed
    }

    private static func highlightPattern(
        in attributed: inout AttributedString,
        pattern: String,
        color: Color,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return
        }

        let string = String(attributed.characters)
        let range = NSRange(string.startIndex..., in: string)

        let matches = regex.matches(in: string, options: [], range: range)

        for match in matches {
            if let swiftRange = Range(match.range, in: string) {
                let attributedRange = AttributedString.Index(swiftRange.lowerBound, within: attributed)!
                    ..< AttributedString.Index(swiftRange.upperBound, within: attributed)!
                attributed[attributedRange].foregroundColor = color
            }
        }
    }
}
