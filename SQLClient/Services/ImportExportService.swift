import Foundation

class ImportExportService {
    static let shared = ImportExportService()
    
    // MARK: - Export
    
    func generateInsertSQL(tableName: String, columns: [String], rows: [[String]]) -> String {
        var sql = "-- Export of table \(tableName)\n"
        
        for row in rows {
            let colNames = columns.joined(separator: ", ")
            let values = row.map { value in
                if value == "NULL" {
                    return "NULL"
                } else if let _ = Double(value), !value.contains("-") { // Basic heuristic for numbers
                    return value
                } else {
                    return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
                }
            }.joined(separator: ", ")
            
            sql += "INSERT INTO \"\(tableName)\" (\(colNames)) VALUES (\(values));\n"
        }
        
        return sql
    }
    
    func generateFullSchemaExport(schema: DatabaseSchema) -> String {
        var sql = "-- Full Database Export: \(schema.name)\n"
        sql += "-- Generated on \(Date())\n\n"
        
        // This is a simplified version. A real one would need to fetch data for all tables.
        // For now, we'll just export table structures.
        for table in schema.tables {
            sql += "CREATE TABLE \"\(table.name)\" (\n"
            let columnDefs = table.columns.map { col in
                var def = "  \"\(col.name)\" \(col.type)"
                if !col.nullable { def += " NOT NULL" }
                if let df = col.defaultValue { def += " DEFAULT \(df)" }
                if col.isPrimaryKey { def += " PRIMARY KEY" }
                return def
            }.joined(separator: ",\n")
            sql += columnDefs + "\n);\n\n"
        }
        
        return sql
    }
    
    func generateCSV(columns: [String], rows: [[String]]) -> String {
        var csv = columns.joined(separator: ",") + "\n"
        
        for row in rows {
            let csvRow = row.map { value in
                // Escape quotes and wrap in quotes if contains comma, quote, or newline
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return value
            }.joined(separator: ",")
            csv += csvRow + "\n"
        }
        
        return csv
    }
    
    func generateJSON(columns: [String], rows: [[String]]) -> String {
        var jsonArray: [[String: String]] = []
        
        for row in rows {
            var jsonObject: [String: String] = [:]
            for (index, column) in columns.enumerated() {
                if index < row.count {
                    jsonObject[column] = row[index]
                }
            }
            jsonArray.append(jsonObject)
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
    
    // MARK: - Import
    
    func parseSQLScript(_ script: String) -> [String] {
        // Simple splitter by semicolon, ignoring comments
        let cleanScript = script.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
            .joined(separator: "\n")
            
        return cleanScript.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
