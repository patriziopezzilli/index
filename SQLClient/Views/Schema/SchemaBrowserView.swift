import SwiftUI

struct SchemaBrowserView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var selectedTable: TableSchema?
    @Binding var insertText: String?

    var filteredTables: [TableSchema] {
        guard let schema = databaseService.currentSchema else { return [] }
        if searchText.isEmpty {
            return schema.tables
        }
        return schema.tables.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if !databaseService.isConnected {
                    NotConnectedView()
                } else if databaseService.currentSchema == nil {
                    LoadSchemaView(isLoading: $isLoading, onLoad: loadSchema)
                } else {
                    SchemaContentView(
                        tables: filteredTables,
                        searchText: $searchText,
                        selectedTable: $selectedTable,
                        onTableTap: { table in
                            insertText = table.name
                        },
                        onRefresh: loadSchema
                    )
                }
            }
            .navigationTitle("Schema")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedTable) { table in
                TableDetailView(table: table, insertText: $insertText)
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
}

struct NotConnectedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text("Not Connected")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Connect to a database to browse its schema")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
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
                    .tint(.white)

                Text("Loading schema...")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(.white.opacity(0.3))

                VStack(spacing: 12) {
                    Text("Schema Not Loaded")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Load the database schema to browse tables and columns")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Button(action: onLoad) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Load Schema")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 180, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
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

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tables) { table in
                        TableRow(table: table, onTap: {
                            selectedTable = table
                        }, onInsert: {
                            onTableTap(table)
                        })
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))

            TextField("Search tables...", text: $text)
                .foregroundColor(.white)
                .autocapitalization(.none)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
}

struct TableRow: View {
    let table: TableSchema
    let onTap: () -> Void
    let onInsert: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "tablecells")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(table.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Label("\(table.columns.count) columns", systemImage: "line.3.horizontal")
                        Label("\(table.rowCount) rows", systemImage: "number")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Button(action: onInsert) {
                    Image(systemName: "arrow.down.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TableDetailView: View {
    let table: TableSchema
    @Binding var insertText: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "tablecells")
                                    .font(.system(size: 28))
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(table.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)

                                HStack(spacing: 12) {
                                    Label("\(table.columns.count) columns", systemImage: "line.3.horizontal")
                                    Label("\(table.rowCount) rows", systemImage: "number")
                                }
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                            }

                            Spacer()
                        }
                        .padding()

                        VStack(spacing: 0) {
                            ForEach(table.columns) { column in
                                ColumnRow(column: column)

                                if column.id != table.columns.last?.id {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Table Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
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
                        .foregroundColor(.white)

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
                                    .fill(Color.red.opacity(0.2))
                            )
                    }
                }

                HStack(spacing: 8) {
                    Text(column.type)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))

                    if let defaultValue = column.defaultValue {
                        Text("default: \(defaultValue)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}
