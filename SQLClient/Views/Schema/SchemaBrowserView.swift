import SwiftUI

struct SchemaBrowserView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedTable: TableSchema?
    @State private var showCreateTable = false
    @State private var tableToDelete: TableSchema?
    @State private var tableToTruncate: TableSchema?
    @State private var tableToInsert: TableSchema?
    @State private var showERDiagram = false
    @Binding var insertText: String?

    var filteredTables: [TableSchema] {
        guard let schema = databaseService.currentWorkspace?.schema else { return [] }
        if searchText.isEmpty {
            return schema.tables
        }
        return schema.tables.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if !databaseService.isConnected {
                    NotConnectedView()
                } else if databaseService.currentWorkspace?.schema == nil {
                    LoadSchemaView(isLoading: $isLoading, onLoad: loadSchema)
                } else {
                    SchemaContentView(
                        tables: filteredTables,
                        searchText: $searchText,
                        selectedTable: $selectedTable,
                        onTableTap: { table in
                            insertText = table.name
                        },
                        onRefresh: loadSchema,
                        onCreateTable: { showCreateTable = true },
                        onDropTable: { tableToDelete = $0 },
                        onTruncateTable: { tableToTruncate = $0 },
                        onInsertRow: { tableToInsert = $0 },
                        onShowERDiagram: { showERDiagram = true }
                    )
                }
            }
            .navigationTitle("Tables")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTable) { table in
                TableDetailView(table: table, insertText: $insertText, onInsertRow: { tableToInsert = $0 })
            }
            .sheet(isPresented: $showCreateTable) {
                CreateTableWizardView()
                    .environmentObject(databaseService)
            }
            .sheet(item: $tableToDelete) { table in
                DropTableConfirmationView(table: table) {
                    dropTable(table)
                }
            }
            .sheet(item: $tableToTruncate) { table in
                TruncateTableView(table: table) {
                    truncateTable(table)
                }
            }
            .sheet(item: $tableToInsert) { table in
                SchemaInsertRowView(table: table)
                    .environmentObject(databaseService)
            }
            .sheet(isPresented: $showERDiagram) {
                if let schema = databaseService.currentWorkspace?.schema {
                    ERDiagramView(schema: schema)
                }
            }
        }
    }

    private func loadSchema() {
        isLoading = true
        Task {
            await databaseService.loadSchema()
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func dropTable(_ table: TableSchema) {
        let dbType = databaseService.currentWorkspace?.connection.type ?? .sqlite
        let quote = dbType == .mysql ? "`" : "\""
        let sql = "DROP TABLE \(quote)\(table.name)\(quote);"

        Task {
            _ = await databaseService.executeQuery(sql)
            await MainActor.run {
                tableToDelete = nil
                loadSchema()
            }
        }
    }

    private func truncateTable(_ table: TableSchema) {
        let dbType = databaseService.currentWorkspace?.connection.type ?? .sqlite
        let quote = dbType == .mysql ? "`" : "\""

        // SQLite doesn't support TRUNCATE, use DELETE instead
        let sql = dbType == .sqlite
            ? "DELETE FROM \(quote)\(table.name)\(quote);"
            : "TRUNCATE TABLE \(quote)\(table.name)\(quote);"

        Task {
            _ = await databaseService.executeQuery(sql)
            await MainActor.run {
                tableToTruncate = nil
                loadSchema()
            }
        }
    }
}

struct NotConnectedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.gray.opacity(0.4))

            VStack(spacing: 12) {
                Text("Not Connected")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Connect to a database to browse its schema")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct LoadSchemaView: View {
    @Binding var isLoading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.blue)

                Text("Loading schema...")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(.gray.opacity(0.4))

                VStack(spacing: 12) {
                    Text("Schema Not Loaded")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text("Load the database schema to browse tables and columns")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: onLoad) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Load Schema")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 180, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
            }
        }
        .padding()
    }
}

struct SchemaContentView: View {
    let tables: [TableSchema]
    @Binding var searchText: String
    @Binding var selectedTable: TableSchema?
    let onTableTap: (TableSchema) -> Void
    let onRefresh: () -> Void
    var onCreateTable: (() -> Void)? = nil
    var onDropTable: ((TableSchema) -> Void)? = nil
    var onTruncateTable: ((TableSchema) -> Void)? = nil
    var onInsertRow: ((TableSchema) -> Void)? = nil
    var onShowERDiagram: (() -> Void)? = nil
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            BrowserSearchBar(text: $searchText)
                .padding()

            if tables.isEmpty && searchText.isEmpty {
                // Empty state with prominent create button
                VStack(spacing: 32) {
                    Spacer()

                    Image(systemName: "tablecells.badge.ellipsis")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundColor(.gray.opacity(0.4))

                    VStack(spacing: 12) {
                        Text("No Tables Yet")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Create your first table to get started")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if let createAction = onCreateTable {
                        Button(action: createAction) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Create Table")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 220, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
                        }
                    }

                    Spacer()
                }
            } else {
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(tables) { table in
                                BrowserTableRow(
                                    table: table,
                                    onTap: { selectedTable = table },
                                    onInsert: { onTableTap(table) },
                                    onDropTable: onDropTable,
                                    onTruncateTable: onTruncateTable,
                                    onInsertRow: onInsertRow
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80) // Space for FAB
                    }
                    .refreshable {
                        isRefreshing = true
                        onRefresh()
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        isRefreshing = false
                    }

                    // Floating Action Button for Create Table
                    if let createAction = onCreateTable {
                        Button(action: createAction) {
                            HStack(spacing: 8) {
                                Image(systemName: "tablecells.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("New Table")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if let erAction = onShowERDiagram {
                        Button(action: erAction) {
                            Image(systemName: "diagram.split.3x3")
                                .foregroundColor(.blue)
                        }
                    }

                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }

                    if let createAction = onCreateTable {
                        Button(action: createAction) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
}

struct BrowserSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search tables...", text: $text)
                .foregroundColor(.primary)
                .autocapitalization(.none)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct BrowserTableRow: View {
    let table: TableSchema
    let onTap: () -> Void
    let onInsert: () -> Void
    var onDropTable: ((TableSchema) -> Void)? = nil
    var onTruncateTable: ((TableSchema) -> Void)? = nil
    var onInsertRow: ((TableSchema) -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "tablecells")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(table.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Label("\(table.columns.count) columns", systemImage: "line.3.horizontal")
                        Label("\(table.rowCount) rows", systemImage: "number")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Structure button - always visible
                Button(action: onTap) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onInsert) {
                    Image(systemName: "arrow.down.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                        )
                }
                .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onTap) {
                Label("View Structure", systemImage: "list.bullet.rectangle")
            }

            Button(action: onInsert) {
                Label("Insert in Editor", systemImage: "arrow.down.left")
            }

            if let insertRow = onInsertRow {
                Button(action: { insertRow(table) }) {
                    Label("Insert Row", systemImage: "plus.rectangle")
                }
            }

            Divider()

            if let truncate = onTruncateTable {
                Button(action: { truncate(table) }) {
                    Label("Truncate Table", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            if let drop = onDropTable {
                Button(role: .destructive, action: { drop(table) }) {
                    Label("Drop Table", systemImage: "trash")
                }
            }
        }
    }
}

struct TableDetailView: View {
    let table: TableSchema
    @Binding var insertText: String?
    let onInsertRow: ((TableSchema) -> Void)?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 60, height: 60)

                            Image(systemName: "tablecells")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(table.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                Label("\(table.columns.count) columns", systemImage: "line.3.horizontal")
                                Label("\(table.rowCount) rows", systemImage: "number")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()

                    VStack(spacing: 0) {
                        ForEach(table.columns) { column in
                            ColumnRow(column: column)

                            if column.id != table.columns.last?.id {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Table Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if let insertRow = onInsertRow {
                        Button(action: { insertRow(table) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.rectangle")
                                Text("Insert Row")
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    Button(action: {
                        insertText = "SELECT * FROM \(table.name);"
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.left")
                            Text("Insert")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

struct ColumnRow: View {
    let column: ColumnSchema

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: column.typeIcon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(column.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

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

                HStack(spacing: 8) {
                    Text(column.type)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.secondary)

                    if let defaultValue = column.defaultValue {
                        Text("default: \(defaultValue)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}
