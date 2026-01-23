import SwiftUI

struct SchemaComparisonView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var sourceConnection: DatabaseConnection?
    @State private var targetConnection: DatabaseConnection?
    @State private var sourceSchema: DatabaseSchema?
    @State private var targetSchema: DatabaseSchema?
    @State private var isLoadingSource = false
    @State private var isLoadingTarget = false
    @State private var comparisonResult: SchemaComparison?
    @State private var showingConnectionPicker = false
    @State private var pickerType: ConnectionType = .source

    enum ConnectionType {
        case source, target
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select Connections to Compare")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)

                        VStack(spacing: 12) {
                            ConnectionSelector(
                                title: "Source Database",
                                connection: sourceConnection,
                                isLoading: isLoadingSource,
                                action: {
                                    pickerType = .source
                                    showingConnectionPicker = true
                                }
                            )

                            ConnectionSelector(
                                title: "Target Database",
                                connection: targetConnection,
                                isLoading: isLoadingTarget,
                                action: {
                                    pickerType = .target
                                    showingConnectionPicker = true
                                }
                            )
                        }
                    }

                    // Compare Button
                    if sourceConnection != nil && targetConnection != nil {
                        Button(action: performComparison) {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                Text("Compare Schemas")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Comparison Results
                    if let result = comparisonResult {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Comparison Results")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)

                            // Summary Stats
                            HStack(spacing: 16) {
                                SchemaStatCard(
                                    title: "Tables in Source",
                                    value: "\(result.sourceTableCount)",
                                    color: .blue
                                )

                                SchemaStatCard(
                                    title: "Tables in Target",
                                    value: "\(result.targetTableCount)",
                                    color: .green
                                )

                                SchemaStatCard(
                                    title: "Differences",
                                    value: "\(result.differences.count)",
                                    color: result.differences.isEmpty ? .green : .orange
                                )
                            }

                            // Differences List
                            if !result.differences.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Schema Differences")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)

                                    ForEach(result.differences) { difference in
                                        DifferenceCard(difference: difference)
                                    }
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.green)

                                    Text("Schemas are identical!")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    Text("No differences found between the selected databases.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Schema Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingConnectionPicker) {
                ConnectionPickerView(
                    connections: databaseService.savedConnections,
                    selectedConnection: pickerType == .source ? $sourceConnection : $targetConnection,
                    onSelect: { connection in
                        loadSchema(for: connection, type: pickerType)
                        showingConnectionPicker = false
                    }
                )
            }
        }
    }

    private func loadSchema(for connection: DatabaseConnection, type: ConnectionType) {
        switch type {
        case .source:
            isLoadingSource = true
        case .target:
            isLoadingTarget = true
        }

        Task {
            do {
                // In a real implementation, you'd connect to the database and load schema
                // For now, we'll simulate loading
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                let mockSchema = DatabaseSchema(
                    name: connection.database,
                    tables: [
                        TableSchema(name: "users", columns: [
                            ColumnSchema(name: "id", type: "INT", nullable: false, isPrimaryKey: true, defaultValue: nil),
                            ColumnSchema(name: "name", type: "VARCHAR(255)", nullable: false, isPrimaryKey: false, defaultValue: nil),
                            ColumnSchema(name: "email", type: "VARCHAR(255)", nullable: false, isPrimaryKey: false, defaultValue: nil)
                        ], foreignKeys: [], rowCount: 0),
                        TableSchema(name: "orders", columns: [
                            ColumnSchema(name: "id", type: "INT", nullable: false, isPrimaryKey: true, defaultValue: nil),
                            ColumnSchema(name: "user_id", type: "INT", nullable: false, isPrimaryKey: false, defaultValue: nil),
                            ColumnSchema(name: "total", type: "DECIMAL(10,2)", nullable: false, isPrimaryKey: false, defaultValue: nil)
                        ], foreignKeys: [], rowCount: 0)
                    ]
                )

                await MainActor.run {
                    switch type {
                    case .source:
                        sourceSchema = mockSchema
                        isLoadingSource = false
                    case .target:
                        targetSchema = mockSchema
                        isLoadingTarget = false
                    }
                }
            } catch {
                await MainActor.run {
                    switch type {
                    case .source:
                        isLoadingSource = false
                    case .target:
                        isLoadingTarget = false
                    }
                }
            }
        }
    }

    private func performComparison() {
        guard let source = sourceSchema, let target = targetSchema else { return }

        var differences: [SchemaDifference] = []

        // Compare table counts
        if source.tables.count != target.tables.count {
            differences.append(SchemaDifference(
                type: .tableCount,
                description: "Different number of tables: \(source.tables.count) vs \(target.tables.count)",
                severity: .warning
            ))
        }

        // Compare tables
        let sourceTableNames = Set(source.tables.map { $0.name })
        let targetTableNames = Set(target.tables.map { $0.name })

        let missingInTarget = sourceTableNames.subtracting(targetTableNames)
        let missingInSource = targetTableNames.subtracting(sourceTableNames)

        for tableName in missingInTarget {
            differences.append(SchemaDifference(
                type: .missingTable,
                description: "Table '\(tableName)' exists in source but not in target",
                severity: .error
            ))
        }

        for tableName in missingInSource {
            differences.append(SchemaDifference(
                type: .missingTable,
                description: "Table '\(tableName)' exists in target but not in source",
                severity: .error
            ))
        }

        // Compare common tables
        for sourceTable in source.tables {
            if let targetTable = target.tables.first(where: { $0.name == sourceTable.name }) {
                // Compare columns
                let sourceColumns = Set(sourceTable.columns.map { $0.name })
                let targetColumns = Set(targetTable.columns.map { $0.name })

                let missingColumnsInTarget = sourceColumns.subtracting(targetColumns)
                let missingColumnsInSource = targetColumns.subtracting(sourceColumns)

                for columnName in missingColumnsInTarget {
                    differences.append(SchemaDifference(
                        type: .missingColumn,
                        description: "Column '\(columnName)' in table '\(sourceTable.name)' exists in source but not in target",
                        severity: .warning
                    ))
                }

                for columnName in missingColumnsInSource {
                    differences.append(SchemaDifference(
                        type: .missingColumn,
                        description: "Column '\(columnName)' in table '\(sourceTable.name)' exists in target but not in source",
                        severity: .warning
                    ))
                }
            }
        }

        comparisonResult = SchemaComparison(
            sourceTableCount: source.tables.count,
            targetTableCount: target.tables.count,
            differences: differences
        )
    }
}

struct ConnectionSelector: View {
    let title: String
    let connection: DatabaseConnection?
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    if let connection = connection {
                        Text(connection.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        Text("\(connection.type.rawValue) • \(connection.database)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select database...")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.blue)
                } else {
                    Image(systemName: connection == nil ? "chevron.right" : "checkmark.circle.fill")
                        .foregroundColor(connection == nil ? .gray : .green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}

struct ConnectionPickerView: View {
    let connections: [DatabaseConnection]
    @Binding var selectedConnection: DatabaseConnection?
    let onSelect: (DatabaseConnection) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(connections) { connection in
                Button(action: {
                    selectedConnection = connection
                    onSelect(connection)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        Text("\(connection.type.rawValue) • \(connection.host):\(connection.port) • \(connection.database)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Select Database")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct SchemaComparison {
    let sourceTableCount: Int
    let targetTableCount: Int
    let differences: [SchemaDifference]
}

struct SchemaDifference: Identifiable {
    let id = UUID()
    let type: DifferenceType
    let description: String
    let severity: Severity

    enum DifferenceType {
        case tableCount, missingTable, missingColumn, columnType
    }

    enum Severity {
        case info, warning, error
    }
}

struct DifferenceCard: View {
    let difference: SchemaDifference

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: severityIcon)
                .foregroundColor(severityColor)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text(difference.description)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var severityIcon: String {
        switch difference.severity {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var severityColor: Color {
        switch difference.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct SchemaStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}