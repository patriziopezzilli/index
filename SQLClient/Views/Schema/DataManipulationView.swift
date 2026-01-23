import SwiftUI

// MARK: - Create Table View

struct CreateTableView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var databaseService: DatabaseService

    @State private var tableName = ""
    @State private var columns: [NewColumnDefinition] = [NewColumnDefinition()]
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Table Name Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Table Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            Image(systemName: "tablecells")
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            TextField("users, products, orders...", text: $tableName)
                                .font(.system(size: 16))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    // Columns Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Columns")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button(action: addColumn) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("Add Column")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                            }
                        }

                        ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                            DataManipulationColumnRow(
                                column: $columns[index],
                                canDelete: columns.count > 1,
                                onDelete: { removeColumn(at: index) }
                            )
                        }
                    }

                    // Error Message
                    if let error = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)

                            Text(error)
                                .font(.system(size: 14))
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(generateSQL())
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
            .background(Color(.systemBackground))
            .navigationTitle("Create Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createTable) {
                        Group {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .disabled(!isFormValid || isCreating)
                }
            }
            .alert("Table Created", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The table '\(tableName)' was created successfully.")
            }
        }
    }

    private var isFormValid: Bool {
        !tableName.isEmpty && columns.allSatisfy { !$0.name.isEmpty && !$0.type.isEmpty }
    }

    private func addColumn() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            columns.append(NewColumnDefinition())
        }
    }

    private func removeColumn(at index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            columns.remove(at: index)
        }
    }

    private func generateSQL() -> String {
        guard !tableName.isEmpty else { return "-- Enter a table name" }

        let dbType = databaseService.currentWorkspace?.connection.type ?? .sqlite
        let quote = dbType == .mysql ? "`" : "\""

        var sql = "CREATE TABLE \(quote)\(tableName)\(quote) (\n"

        let columnDefs = columns.compactMap { column -> String? in
            guard !column.name.isEmpty else { return nil }

            var def = "  \(quote)\(column.name)\(quote) \(column.type)"

            if column.isPrimaryKey {
                def += " PRIMARY KEY"
                if column.autoIncrement {
                    def += dbType == .sqlite ? " AUTOINCREMENT" : " AUTO_INCREMENT"
                }
            }

            if !column.nullable && !column.isPrimaryKey {
                def += " NOT NULL"
            }

            if !column.defaultValue.isEmpty {
                def += " DEFAULT '\(column.defaultValue)'"
            }

            return def
        }

        sql += columnDefs.joined(separator: ",\n")
        sql += "\n);"

        return sql
    }

    private func createTable() {
        isCreating = true
        errorMessage = nil

        let sql = generateSQL()

        Task {
            let result = await databaseService.executeQuery(sql)

            await MainActor.run {
                isCreating = false

                if let error = result.error {
                    errorMessage = error
                } else {
                    showingSuccess = true
                    // Reload schema
                    Task {
                        await databaseService.loadSchema()
                    }
                }
            }
        }
    }
}

struct NewColumnDefinition: Identifiable {
    let id = UUID()
    var name: String = ""
    var type: String = "TEXT"
    var isPrimaryKey: Bool = false
    var nullable: Bool = true
    var autoIncrement: Bool = false
    var defaultValue: String = ""
}

struct DataManipulationColumnRow: View {
    @Binding var column: NewColumnDefinition
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var isExpanded = false

    private let commonTypes = ["TEXT", "INTEGER", "REAL", "BLOB", "VARCHAR(255)", "INT", "BOOLEAN", "TIMESTAMP", "DATE"]

    var body: some View {
        VStack(spacing: 12) {
            // Main row
            HStack(spacing: 12) {
                // Column name
                TextField("Column name", text: $column.name)
                    .font(.system(size: 15))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .frame(maxWidth: .infinity)

                // Type picker
                Menu {
                    ForEach(commonTypes, id: \.self) { type in
                        Button(type) {
                            column.type = type
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(column.type)
                            .font(.system(size: 13, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }

                // Expand/collapse
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }

                // Delete
                if canDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                    }
                }
            }

            // Expanded options
            if isExpanded {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Toggle(isOn: $column.isPrimaryKey) {
                            HStack(spacing: 6) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.yellow)
                                Text("Primary Key")
                            }
                            .font(.system(size: 14))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .yellow))

                        if column.isPrimaryKey {
                            Toggle(isOn: $column.autoIncrement) {
                                Text("Auto Increment")
                                    .font(.system(size: 14))
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }
                    }

                    HStack(spacing: 16) {
                        Toggle(isOn: $column.nullable) {
                            Text("Nullable")
                                .font(.system(size: 14))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                        .disabled(column.isPrimaryKey)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            TextField("Value", text: $column.defaultValue)
                                .font(.system(size: 14))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Drop Table Confirmation View

struct DropTableConfirmationView: View {
    let table: TableSchema
    let onConfirm: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var confirmText = ""
    @State private var isDropping = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.red)
                }

                // Warning text
                VStack(spacing: 12) {
                    Text("Drop Table")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("You are about to permanently delete the table")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text(table.name)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )

                    Text("This will delete \(table.rowCount) rows and cannot be undone.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Confirmation input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Type '\(table.name)' to confirm")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Table name", text: $confirmText)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(confirmText == table.name ? Color.red : Color.clear, lineWidth: 2)
                        )
                }
                .padding(.horizontal)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        isDropping = true
                        onConfirm()
                    }) {
                        HStack(spacing: 8) {
                            if isDropping {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text("Drop Table")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(confirmText == table.name ? Color.red : Color.red.opacity(0.5))
                        )
                    }
                    .disabled(confirmText != table.name || isDropping)

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Confirm Delete")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Truncate Table View

struct TruncateTableView: View {
    let table: TableSchema
    let onConfirm: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var isTruncating = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                }

                // Warning text
                VStack(spacing: 12) {
                    Text("Truncate Table")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("This will delete all data in")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text(table.name)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )

                    Text("\(table.rowCount) rows will be permanently deleted.\nThe table structure will remain intact.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        isTruncating = true
                        onConfirm()
                    }) {
                        HStack(spacing: 8) {
                            if isTruncating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Truncate Table")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange)
                        )
                    }
                    .disabled(isTruncating)

                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Confirm Truncate")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Insert Row View

struct InsertRowView: View {
    let table: TableSchema
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var databaseService: DatabaseService

    @State private var values: [String: String] = [:]
    @State private var isInserting = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Table info
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 48, height: 48)

                            Image(systemName: "plus.rectangle")
                                .font(.system(size: 22))
                                .foregroundColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Insert into \(table.name)")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)

                            Text("\(table.columns.count) columns")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )

                    // Column inputs
                    ForEach(table.columns.filter { !($0.isPrimaryKey && isAutoIncrement($0)) }) { column in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(column.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)

                                Text(column.type)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.tertiarySystemFill))
                                    )

                                if !column.nullable {
                                    Text("Required")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Color.red.opacity(0.1))
                                        )
                                }
                            }

                            TextField(
                                column.defaultValue ?? "Enter value...",
                                text: Binding(
                                    get: { values[column.name] ?? "" },
                                    set: { values[column.name] = $0 }
                                )
                            )
                            .font(.system(size: 16))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                    }

                    // Error message
                    if let error = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)

                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color(.systemBackground))
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
                        if isInserting {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            Text("Insert")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isInserting)
                }
            }
            .alert("Row Inserted", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("The row was inserted successfully.")
            }
        }
    }

    private func isAutoIncrement(_ column: ColumnSchema) -> Bool {
        // Simple heuristic - primary keys named "id" are usually auto-increment
        return column.isPrimaryKey && column.name.lowercased() == "id"
    }

    private func insertRow() {
        isInserting = true
        errorMessage = nil

        let dbType = databaseService.currentWorkspace?.connection.type ?? .sqlite
        let quote = dbType == .mysql ? "`" : "\""

        let columnsWithValues = values.filter { !$0.value.isEmpty }
        let columnNames = columnsWithValues.keys.map { "\(quote)\($0)\(quote)" }.joined(separator: ", ")
        let columnValues = columnsWithValues.values.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" }.joined(separator: ", ")

        let sql = "INSERT INTO \(quote)\(table.name)\(quote) (\(columnNames)) VALUES (\(columnValues));"

        Task {
            let result = await databaseService.executeQuery(sql)

            await MainActor.run {
                isInserting = false

                if let error = result.error {
                    errorMessage = error
                } else {
                    showingSuccess = true
                }
            }
        }
    }
}

// MARK: - Table Actions Menu

struct TableActionsMenu: View {
    let table: TableSchema
    @Binding var showCreateTable: Bool
    @Binding var showDropTable: Bool
    @Binding var showTruncateTable: Bool
    @Binding var showInsertRow: Bool

    var body: some View {
        Menu {
            Button(action: { showInsertRow = true }) {
                Label("Insert Row", systemImage: "plus.rectangle")
            }

            Divider()

            Button(action: { showTruncateTable = true }) {
                Label("Truncate Table", systemImage: "arrow.triangle.2.circlepath")
            }

            Button(role: .destructive, action: { showDropTable = true }) {
                Label("Drop Table", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundColor(.blue)
        }
    }
}

#Preview("Create Table") {
    CreateTableView()
        .environmentObject(DatabaseService())
}

#Preview("Drop Confirmation") {
    DropTableConfirmationView(
        table: TableSchema(name: "users", columns: [], rowCount: 150),
        onConfirm: {}
    )
}
