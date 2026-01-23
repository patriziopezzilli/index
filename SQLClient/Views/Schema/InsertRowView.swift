import SwiftUI

struct SchemaInsertRowView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss

    let table: TableSchema
    @State private var columnValues: [String: String] = [:]
    @State private var isInserting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Progress / Header
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Step 1 of 1")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                
                                Spacer()
                            }
                            
                            HStack(spacing: 12) {
                                Image(systemName: "plus.square.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Insert New Row")
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Text("Table: \(table.name)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Simple progress line
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(height: 4)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )

                        // Column Fields
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("FIELD DEFINITIONS")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            ForEach(table.columns) { column in
                                ColumnInputField(
                                    column: column,
                                    value: Binding(
                                        get: { columnValues[column.name] ?? "" },
                                        set: { columnValues[column.name] = $0 }
                                    )
                                )
                            }
                        }

                        // Error Message
                        if let error = errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)

                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }

                        // SQL Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SQL Preview")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text(generateInsertSQL())
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Insert Row")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: insertRow) {
                        Group {
                            if isInserting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Insert")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(isInserting)
                }
            }
            .alert("Row Inserted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The row was inserted successfully into \(table.name).")
            }
        }
    }

    private func insertRow() {
        errorMessage = nil
        isInserting = true

        let sql = generateInsertSQL()

        Task {
            let result = await databaseService.executeQuery(sql)

            await MainActor.run {
                isInserting = false

                if result.isSuccess {
                    showSuccess = true
                } else {
                    errorMessage = result.error ?? "Failed to insert row"
                }
            }
        }
    }

    private func generateInsertSQL() -> String {
        let dbType = databaseService.currentWorkspace?.connection.type ?? .sqlite
        let quote = dbType == .mysql ? "`" : "\""

        // Get columns that have values
        let columnsWithValues = table.columns.filter { column in
            if let value = columnValues[column.name], !value.isEmpty {
                return true
            }
            return false
        }

        guard !columnsWithValues.isEmpty else {
            return "-- Enter values for at least one column"
        }

        let columnNames = columnsWithValues.map { "\(quote)\($0.name)\(quote)" }.joined(separator: ", ")
        let values = columnsWithValues.map { column -> String in
            let value = columnValues[column.name] ?? ""

            // Handle NULL
            if value.uppercased() == "NULL" {
                return "NULL"
            }

            // Quote strings for TEXT/VARCHAR columns
            if column.type.uppercased().contains("TEXT") ||
               column.type.uppercased().contains("VARCHAR") ||
               column.type.uppercased().contains("CHAR") {
                return "'\(value.replacingOccurrences(of: "'", with: "''"))'"
            }

            return value
        }.joined(separator: ", ")

        return "INSERT INTO \(quote)\(table.name)\(quote) (\(columnNames)) VALUES (\(values));"
    }
}

struct ColumnInputField: View {
    let column: ColumnSchema
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: column.typeIcon)
                    .foregroundColor(.blue)
                    .frame(width: 20)

                Text(column.name)
                    .font(.system(size: 15, weight: .medium))

                Text(column.type)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                if column.isPrimaryKey {
                    Text("PK")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.yellow.opacity(0.2))
                        )
                }

                if !column.nullable {
                    Text("REQUIRED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.15))
                        )
                }
            }

            TextField(placeholderText, text: $value)
                .font(.system(size: 15))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(!column.nullable && value.isEmpty ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var placeholderText: String {
        if column.isPrimaryKey && column.type.uppercased().contains("INT") {
            return "Auto-increment (leave empty)"
        } else if column.nullable {
            return "NULL or enter value..."
        } else {
            return "Enter value (required)"
        }
    }
}
