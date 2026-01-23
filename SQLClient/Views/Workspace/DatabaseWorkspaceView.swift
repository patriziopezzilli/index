import SwiftUI
import UniformTypeIdentifiers

struct DatabaseWorkspaceView: View {
    @EnvironmentObject var dbService: DatabaseService
    @ObservedObject var workspace: WorkspaceTab
    @Binding var isSidebarVisible: Bool
    @State private var exportSQL: String?
    @State private var showingBackupExporter = false
    @State private var isImporting = false
    @State private var isExportingBackup = false
    @State private var importError: String?
    @State private var showingSidebarSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        Group {
            if isCompact {
                // iPhone Layout - sidebar as sheet
                iPhoneLayout
            } else {
                // iPad Layout - sidebar as panel
                iPadLayout
            }
        }
        .task {
            if workspace.schema == nil {
                await dbService.loadSchema(for: workspace)
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "sql")!],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .fileExporter(
            isPresented: $showingBackupExporter,
            document: SQLDocument(text: exportSQL ?? ""),
            contentType: .init(filenameExtension: "sql")!,
            defaultFilename: "\(workspace.schema?.name ?? "database")_backup.sql"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
        .overlay {
            if isExportingBackup {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Preparing Backup...")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text("This may take a moment for large databases")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(40)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            // Compact Header
            CompactWorkspaceHeader(
                workspace: workspace,
                onShowSidebar: { showingSidebarSheet = true }
            )

            WorkspaceSubTabBar(workspace: workspace)

            // Content
            ZStack {
                if let currentTab = workspace.currentSubTab {
                    switch currentTab.type {
                    case .table:
                        if let tableName = currentTab.tableContext {
                            TableDataView(workspace: workspace, tableName: tableName)
                                .id(currentTab.id)
                                .transition(.opacity)
                        }
                    case .editor:
                        SQLEditorView(queryToRun: $workspace.queryToRun)
                            .id(currentTab.id)
                            .transition(.move(edge: .bottom))
                    case .erModel:
                        ERModelView(workspace: workspace)
                            .id(currentTab.id)
                            .transition(.opacity)
                    }
                } else {
                    CompactWelcomeView(onShowSidebar: { showingSidebarSheet = true })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: workspace.selectedSubTabId)
        }
        .sheet(isPresented: $showingSidebarSheet) {
            NavigationStack {
                SchemaSidebarView(
                    workspace: workspace,
                    onImport: {
                        showingSidebarSheet = false
                        isImporting = true
                    },
                    onBackup: {
                        showingSidebarSheet = false
                        isExportingBackup = true
                        Task { @MainActor in
                            if let sql = workspace.generateBackupSQL() {
                                exportSQL = sql
                                isExportingBackup = false
                                showingBackupExporter = true
                            } else {
                                isExportingBackup = false
                            }
                        }
                    }
                )
                .navigationTitle("Schema")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingSidebarSheet = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onChange(of: workspace.selectedSubTabId) { _, _ in
            // Auto-close sidebar when a selection is made (table, ER model, etc.)
            if showingSidebarSheet {
                showingSidebarSheet = false
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Sidebar / Schema Panel
            if isSidebarVisible {
                SchemaSidebarView(
                    workspace: workspace,
                    onImport: { isImporting = true },
                    onBackup: {
                        isExportingBackup = true
                        Task { @MainActor in
                            if let sql = workspace.generateBackupSQL() {
                                exportSQL = sql
                                isExportingBackup = false
                                showingBackupExporter = true
                            } else {
                                isExportingBackup = false
                            }
                        }
                    }
                )
                .frame(width: 320)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Divider()

            // Main Workspace Area
            VStack(spacing: 0) {
                WorkspaceHeader(
                    isSidebarVisible: $isSidebarVisible,
                    isImporting: $isImporting,
                    workspace: workspace,
                    connectionName: workspace.connection.name,
                    onImport: handleImport
                )

                WorkspaceSubTabBar(workspace: workspace)

                ZStack {
                    if let currentTab = workspace.currentSubTab {
                        switch currentTab.type {
                        case .table:
                            if let tableName = currentTab.tableContext {
                                TableDataView(workspace: workspace, tableName: tableName)
                                    .id(currentTab.id)
                                    .transition(.opacity)
                            }
                        case .editor:
                            SQLEditorView(queryToRun: $workspace.queryToRun)
                                .id(currentTab.id)
                                .transition(.move(edge: .bottom))
                        case .erModel:
                            ERModelView(workspace: workspace)
                                .id(currentTab.id)
                                .transition(.opacity)
                        }
                    } else {
                        WelcomeWorkspaceView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: workspace.selectedSubTabId)
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let sql = try String(contentsOf: url)
                let queries = ImportExportService.shared.parseSQLScript(sql)
                Task {
                    for query in queries {
                        _ = await dbService.executeQuery(query, in: workspace)
                    }
                    await dbService.loadSchema(for: workspace)
                }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

struct WorkspaceHeader: View {
    @Binding var isSidebarVisible: Bool
    @Binding var isImporting: Bool
    @ObservedObject var workspace: WorkspaceTab
    let connectionName: String
    let onImport: (Result<[URL], Error>) -> Void
    @EnvironmentObject var dbService: DatabaseService

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Button(action: { withAnimation(.spring()) { isSidebarVisible.toggle() } }) {
                    Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .shadow(color: .green.opacity(0.5), radius: 4)

                        Text(connectionName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Transaction indicator
                        TransactionIndicator(workspace: workspace)
                    }

                    Text(workspace.connection.displayInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Transaction quick menu
                TransactionQuickMenu(workspace: workspace)
                    .environmentObject(dbService)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            Divider()
        }
    }
}

// MARK: - Compact Header for iPhone

struct CompactWorkspaceHeader: View {
    @ObservedObject var workspace: WorkspaceTab
    let onShowSidebar: () -> Void
    @EnvironmentObject var dbService: DatabaseService

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onShowSidebar) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .semibold))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(workspace.connection.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text(workspace.schema?.name ?? "Loading...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)

                Spacer()

                // Connection status
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Connected")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // Transaction indicator
                TransactionIndicator(workspace: workspace)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)

            Divider()
        }
    }
}

// MARK: - Compact Welcome View for iPhone

struct CompactWelcomeView: View {
    let onShowSidebar: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Ready to Explore")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Tap the header to browse tables and start querying.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button(action: onShowSidebar) {
                Label("Browse Schema", systemImage: "list.bullet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).opacity(0.3))
    }
}

// MARK: - Table Data View

struct TableDataView: View {
    @ObservedObject var workspace: WorkspaceTab
    let tableName: String
    @EnvironmentObject var dbService: DatabaseService
    @State private var result: QueryResult?
    @State private var isLoading = false
    @State private var currentPage = 1
    
    var body: some View {
        ZStack {
            if let result = result {
                QueryResultView(result: result, onPageChange: { newPage in
                    currentPage = newPage
                    Task {
                        await loadData()
                    }
                })
                .opacity(isLoading ? 0.3 : 1.0)
            } else if !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Error loading table data")
                        .foregroundColor(.secondary)
                }
            }
            
            if isLoading {
                ProgressView {
                    Text("Fetching data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: tableName) {
            currentPage = 1
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        result = await dbService.fetchTableData(tableName: tableName, page: currentPage, in: workspace)
        isLoading = false
    }
}

struct TableStructureView: View {
    let table: TableSchema
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(table.name)
                            .font(.title2)
                            .bold()
                        Text("\(table.rowCount) rows · \(table.columns.count) columns")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                VStack(spacing: 0) {
                    ForEach(table.columns) { column in
                        HStack {
                            Image(systemName: column.isPrimaryKey ? "key.fill" : "app.dashed")
                                .foregroundColor(column.isPrimaryKey ? .yellow : .blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading) {
                                Text(column.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(column.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospaced()
                            }
                            
                            Spacer()
                            
                            if !column.nullable {
                                Text("NOT NULL")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding()
                        
                        Divider().padding(.leading, 50)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct WorkspaceSubTabBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var workspace: WorkspaceTab
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.subTabs) { tab in
                    WorkspaceSubTabButton(
                        tab: tab,
                        isSelected: workspace.selectedSubTabId == tab.id,
                        onSelect: { workspace.selectedSubTabId = tab.id },
                        onClose: { workspace.closeSubTab(tab.id) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: appState.displayDensity == .compact ? 34 : 44)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct WorkspaceSubTabButton: View {
    @EnvironmentObject var appState: AppState
    let tab: WorkspaceSubTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    private var fontSize: CGFloat {
        appState.displayDensity == .compact ? 12 : 14
    }
    
    private var verticalPadding: CGFloat {
        appState.displayDensity == .compact ? 8 : 12
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: tab.type == .table ? "tablecells" : "terminal")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .blue : .secondary)
                    
                    Text(tab.name)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(4)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .padding(.vertical, 4)
        )
        .padding(.horizontal, 4)
    }
}

struct WelcomeWorkspaceView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(spacing: 8) {
                Text("Ready to Explore")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select a table from the sidebar or start a new SQL sheet.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).opacity(0.3))
    }
}
struct SQLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, UTType(filenameExtension: "sql")!] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
