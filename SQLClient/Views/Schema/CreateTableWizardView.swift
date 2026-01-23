import SwiftUI

struct CreateTableWizardView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var tableName = ""
    @State private var columns: [ColumnDefinition] = []
    @State private var isCreating = false
    @State private var errorMessage: String?

    let totalSteps = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressBar(currentStep: currentStep, totalSteps: totalSteps)
                    .padding()

                TabView(selection: $currentStep) {
                    Step1TableName(tableName: $tableName)
                        .tag(0)

                    Step2ColumnDefinitions(columns: $columns)
                        .tag(1)

                    Step3Review(tableName: tableName, columns: columns)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                NavigationButtons(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    canProceed: canProceedToNextStep,
                    isCreating: isCreating,
                    onNext: { withAnimation { currentStep += 1 } },
                    onBack: { withAnimation { currentStep -= 1 } },
                    onCreate: createTable
                )
                .padding()
            }
            .navigationTitle("Create Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var canProceedToNextStep: Bool {
        switch currentStep {
        case 0:
            return !tableName.isEmpty && tableName.range(of: "^[a-zA-Z_][a-zA-Z0-9_]*$", options: .regularExpression) != nil
        case 1:
            return !columns.isEmpty && columns.allSatisfy { !$0.name.isEmpty }
        case 2:
            return true
        default:
            return false
        }
    }

    private func createTable() {
        guard canProceedToNextStep else { return }

        isCreating = true
        errorMessage = nil

        let sql = generateCreateTableSQL()

        Task {
            let result = await databaseService.executeQuery(sql)

            if result.success {
                await databaseService.loadSchema()
            }

            await MainActor.run {
                isCreating = false

                if result.success {
                    dismiss()
                } else {
                    errorMessage = result.error ?? "Failed to create table"
                }
            }
        }
    }

    private func generateCreateTableSQL() -> String {
        var sql = "CREATE TABLE \(tableName) (\n"

        let columnDefinitions = columns.map { col -> String in
            var def = "  \(col.name) \(col.type.rawValue)"

            if col.isPrimaryKey {
                def += " PRIMARY KEY"
                if col.autoIncrement {
                    def += " AUTOINCREMENT"
                }
            }

            if !col.nullable && !col.isPrimaryKey {
                def += " NOT NULL"
            }

            if let defaultValue = col.defaultValue, !defaultValue.isEmpty {
                def += " DEFAULT \(defaultValue)"
            }

            return def
        }

        sql += columnDefinitions.joined(separator: ",\n")
        sql += "\n);"

        return sql
    }
}

struct ColumnDefinition: Identifiable {
    let id = UUID()
    var name: String = ""
    var type: ColumnType = .text
    var isPrimaryKey: Bool = false
    var autoIncrement: Bool = false
    var nullable: Bool = true
    var defaultValue: String?
}

enum ColumnType: String, CaseIterable {
    case integer = "INTEGER"
    case text = "TEXT"
    case real = "REAL"
    case blob = "BLOB"

    var icon: String {
        switch self {
        case .integer: return "number"
        case .text: return "textformat"
        case .real: return "number.circle"
        case .blob: return "doc.fill"
        }
    }
}

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

struct Step1TableName: View {
    @Binding var tableName: String

    var isValid: Bool {
        !tableName.isEmpty && tableName.range(of: "^[a-zA-Z_][a-zA-Z0-9_]*$", options: .regularExpression) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "1.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Table Name")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Choose a name for your table")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter table name", text: $tableName)
                            .font(.system(size: 18, design: .monospaced))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isValid ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
                            )
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        if !tableName.isEmpty && !isValid {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)

                                Text("Must start with letter or underscore, contain only letters, numbers, and underscores")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Guidelines")
                        .font(.headline)
                        .foregroundColor(.primary)

                    GuidelineRow(icon: "checkmark.circle.fill", text: "Start with a letter or underscore", color: .green)
                    GuidelineRow(icon: "checkmark.circle.fill", text: "Use only letters, numbers, and underscores", color: .green)
                    GuidelineRow(icon: "checkmark.circle.fill", text: "Keep it descriptive and concise", color: .green)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                Spacer(minLength: 100)
            }
            .padding()
        }
    }
}

struct Step2ColumnDefinitions: View {
    @Binding var columns: [ColumnDefinition]
    @State private var showingAddColumn = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "2.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Define Columns")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Add columns to your table")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()

            if columns.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))

                    Text("No columns yet")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Add at least one column to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(columns) { column in
                            ColumnDefinitionRow(column: column, onDelete: {
                                withAnimation {
                                    columns.removeAll { $0.id == column.id }
                                }
                            }, onEdit: {
                                if let index = columns.firstIndex(where: { $0.id == column.id }) {
                                    columns[index] = column
                                }
                            })
                        }
                    }
                    .padding()
                }
            }

            Button(action: {
                withAnimation {
                    columns.append(ColumnDefinition())
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Column")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .padding()
        }
    }
}

struct ColumnDefinitionRow: View {
    @State var column: ColumnDefinition
    let onDelete: () -> Void
    let onEdit: () -> Void
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: column.type.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                if isExpanded {
                    TextField("Column name", text: $column.name)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                } else {
                    Text(column.name.isEmpty ? "Unnamed" : column.name)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(column.name.isEmpty ? .secondary : .primary)
                }

                Spacer()

                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()

            if isExpanded {
                VStack(spacing: 16) {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Type", selection: $column.type) {
                            ForEach(ColumnType.allCases, id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.rawValue)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(spacing: 12) {
                        Toggle(isOn: $column.isPrimaryKey) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.yellow)
                                Text("Primary Key")
                            }
                        }

                        if column.isPrimaryKey && column.type == .integer {
                            Toggle(isOn: $column.autoIncrement) {
                                HStack {
                                    Image(systemName: "plus.forwardslash.minus")
                                        .foregroundColor(.blue)
                                    Text("Auto Increment")
                                }
                            }
                            .disabled(!column.isPrimaryKey)
                        }

                        if !column.isPrimaryKey {
                            Toggle(isOn: $column.nullable) {
                                HStack {
                                    Image(systemName: "questionmark.circle")
                                        .foregroundColor(.orange)
                                    Text("Nullable")
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "equal.circle")
                                        .foregroundColor(.purple)
                                    Text("Default Value")
                                }
                                .font(.system(size: 14))

                                TextField("Optional", text: Binding(
                                    get: { column.defaultValue ?? "" },
                                    set: { column.defaultValue = $0.isEmpty ? nil : $0 }
                                ))
                                .font(.system(size: 14, design: .monospaced))
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .onChange(of: column) { _, _ in
            onEdit()
        }
    }
}

struct Step3Review: View {
    let tableName: String
    let columns: [ColumnDefinition]

    var sqlPreview: String {
        var sql = "CREATE TABLE \(tableName) (\n"

        let columnDefinitions = columns.map { col -> String in
            var def = "  \(col.name) \(col.type.rawValue)"

            if col.isPrimaryKey {
                def += " PRIMARY KEY"
                if col.autoIncrement {
                    def += " AUTOINCREMENT"
                }
            }

            if !col.nullable && !col.isPrimaryKey {
                def += " NOT NULL"
            }

            if let defaultValue = col.defaultValue, !defaultValue.isEmpty {
                def += " DEFAULT \(defaultValue)"
            }

            return def
        }

        sql += columnDefinitions.joined(separator: ",\n")
        sql += "\n);"

        return sql
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Image(systemName: "3.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review & Create")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Review your table structure")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "tablecells")
                            .foregroundColor(.blue)
                        Text("Table: \(tableName)")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Columns (\(columns.count))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ForEach(columns) { column in
                            HStack(spacing: 12) {
                                Image(systemName: column.type.icon)
                                    .foregroundColor(.blue)
                                    .frame(width: 20)

                                Text(column.name)
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))

                                Text(column.type.rawValue)
                                    .font(.caption)
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
                                    Text("NOT NULL")
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
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.purple)
                        Text("SQL Preview")
                            .font(.headline)
                    }

                    Text(sqlPreview)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemBackground))
                        )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                Spacer(minLength: 100)
            }
            .padding()
        }
    }
}

struct NavigationButtons: View {
    let currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    let isCreating: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onCreate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }

            if currentStep < totalSteps - 1 {
                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canProceed ? Color.blue : Color.blue.opacity(0.5))
                    )
                }
                .disabled(!canProceed)
            } else {
                Button(action: onCreate) {
                    HStack {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isCreating ? "Creating..." : "Create Table")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(canProceed && !isCreating ? Color.green : Color.green.opacity(0.5))
                    )
                }
                .disabled(!canProceed || isCreating)
            }
        }
    }
}

struct GuidelineRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}
