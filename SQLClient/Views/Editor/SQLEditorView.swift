import SwiftUI

struct SQLEditorView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @StateObject private var tabManager = QueryTabManager()
    @State private var showingSaveDialog = false
    @State private var showingSchemaSheet = false
    @State private var showingSavedQueriesSheet = false
    @State private var schemaInsertText: String?
    @State private var savedQueryLoadText: String?
    @Binding var queryToRun: String?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if !databaseService.isConnected {
                NoConnectionView()
            } else {
                VStack(spacing: 0) {
                    TabBar(
                        tabs: tabManager.tabs,
                        selectedTab: $tabManager.selectedTab,
                        onAddTab: { tabManager.addTab() },
                        onCloseTab: { tab in tabManager.closeTab(tab) }
                    )

                    if let currentTab = tabManager.currentTab {
                        TabContentView(
                            tab: currentTab,
                            databaseService: databaseService
                        )
                        
                        EditorActionBar(tab: currentTab, onExecute: {
                            executeQuery(for: currentTab)
                        })
                    }
                }
            }
        }
        .animation(.spring(), value: tabManager.currentTab?.query.isEmpty)
        .animation(.spring(), value: tabManager.currentTab?.isExecuting)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(action: { showingSavedQueriesSheet = true }) {
                        Label("Saved Queries", systemImage: "folder")
                    }

                    Divider()

                    Button(action: { tabManager.currentTab?.query = "" }) {
                        Label("Clear Query", systemImage: "trash")
                    }
                    
                    Divider()

                    Button(action: { showingSaveDialog = true }) {
                        Label("Save Query", systemImage: "square.and.arrow.down")
                    }
                    .disabled(tabManager.currentTab?.query.isEmpty ?? true)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if let currentTab = tabManager.currentTab {
                    EditorToolbarButtons(
                        tab: currentTab,
                        onFormat: { formatQuery(for: currentTab) },
                        onExecute: { executeQuery(for: currentTab) }
                    )
                }
            }
        }
        .sheet(isPresented: $showingSaveDialog) {
            if let tab = tabManager.currentTab {
                SaveQueryDialog(query: tab.query, onSave: { name, category in
                    databaseService.saveQuery(name: name, query: tab.query, category: category)
                    showingSaveDialog = false
                })
            }
        }
        .sheet(isPresented: $showingSchemaSheet) {
            SchemaBrowserView(insertText: $schemaInsertText)
        }
        .sheet(isPresented: $showingSavedQueriesSheet) {
            SavedQueriesView(loadQuery: $savedQueryLoadText)
        }
        .onChange(of: schemaInsertText) { _, newValue in
            if let text = newValue, let tab = tabManager.currentTab {
                tab.query += (tab.query.isEmpty ? "" : "\n") + text
                schemaInsertText = nil
            }
        }
        .onChange(of: savedQueryLoadText) { _, newValue in
            if let text = newValue {
                tabManager.addTab(withQuery: text)
                savedQueryLoadText = nil
            }
        }
        .onChange(of: queryToRun) { _, newValue in
            if let query = newValue {
                tabManager.addTab(withQuery: query)
                queryToRun = nil
            }
        }
    }

    private func executeQuery(for tab: QueryTab) {
        tab.isExecuting = true
        tab.result = nil // Clear results while loading

        tab.executionTask = Task {
            let result = await databaseService.executeQuery(tab.query)

            if Task.isCancelled { return }

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    tab.result = result
                    tab.isExecuting = false
                    tab.executionTask = nil
                }
            }
        }
    }

    private func formatQuery(for tab: QueryTab) {
        let formatted = SQLFormatter.format(tab.query)
        tab.query = formatted
    }
}

class QueryTabManager: ObservableObject {
    @Published var tabs: [QueryTab] = []
    @Published var selectedTab: QueryTab?

    init() {
        addTab()
    }

    var currentTab: QueryTab? {
        selectedTab ?? tabs.first
    }

    func addTab(withQuery query: String = "") {
        let newTab = QueryTab(query: query)
        tabs.append(newTab)
        selectedTab = newTab
    }

    func closeTab(_ tab: QueryTab) {
        guard tabs.count > 1 else { return }

        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs.remove(at: index)

            if selectedTab?.id == tab.id {
                selectedTab = tabs[max(0, index - 1)]
            }
        }
    }
}

struct TabBar: View {
    let tabs: [QueryTab]
    @Binding var selectedTab: QueryTab?
    let onAddTab: () -> Void
    let onCloseTab: (QueryTab) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab?.id == tab.id,
                        onSelect: { selectedTab = tab },
                        onClose: { onCloseTab(tab) }
                    )
                }

                Button(action: onAddTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .frame(height: 44)
        .background(Color(.secondarySystemBackground))
    }
}

struct TabButton: View {
    @ObservedObject var tab: QueryTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    if tab.isExecuting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.blue)
                    }

                    Text(tab.name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            .padding(.trailing, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(.systemBackground) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.gray.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

struct TabContentView: View {
    @ObservedObject var tab: QueryTab
    @ObservedObject var databaseService: DatabaseService

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Editor on top
                SQLEditorWithAutocomplete(
                    text: Binding(
                        get: { tab.query },
                        set: { newValue in
                            tab.query = newValue
                            tab.updateName(from: newValue)
                        }
                    ),
                    onFormat: {
                        tab.query = SQLFormatter.format(tab.query)
                    }
                )
                .frame(height: geometry.size.height * 0.5)

                Divider()

                // Results below
                ZStack {
                    if let result = tab.result {
                        QueryResultView(result: result)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "tablecells.badge.ellipsis")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.3))
                            Text("No results yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Type your query and click 'Run Query' below")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground).opacity(0.3))
                    }
                }
                .frame(height: geometry.size.height * 0.5)
            }
        }
    }
}

struct NoConnectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.gray.opacity(0.4))

            VStack(spacing: 12) {
                Text("No Active Connection")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Connect to a database to start executing queries")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

struct SaveQueryDialog: View {
    let query: String
    let onSave: (String, String) -> Void

    @State private var name = ""
    @State private var category = "Select"
    @Environment(\.dismiss) var dismiss

    let categories = ["Select", "Insert", "Update", "Delete", "Create", "Drop", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Query Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("My Query", text: $name)
                            .font(.system(size: 16))
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Query Preview")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(query)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    Button(action: {
                        onSave(name, category)
                    }) {
                        Text("Save Query")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(name.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                            )
                    }
                    .disabled(name.isEmpty)
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Save Query")
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
}

struct EditorActionBar: View {
    @ObservedObject var tab: QueryTab
    let onExecute: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: {
                if tab.isExecuting {
                    tab.cancelQuery()
                } else {
                    onExecute()
                }
            }) {
                HStack(spacing: 8) {
                    if tab.isExecuting {
                        Image(systemName: "stop.fill")
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(tab.isExecuting ? "Cancel Query" : "Run Query")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(tab.isExecuting ? Color.red : (tab.query.isEmpty ? Color.blue.opacity(0.3) : Color.blue))
                        .shadow(color: tab.isExecuting ? .red.opacity(0.2) : (tab.query.isEmpty ? .clear : .blue.opacity(0.2)), radius: 8, y: 4)
                )
            }
            .disabled(tab.query.isEmpty && !tab.isExecuting)
            
            Spacer()
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
}

struct EditorToolbarButtons: View {
    @ObservedObject var tab: QueryTab
    let onFormat: () -> Void
    let onExecute: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onFormat) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.secondary)
            }
            .disabled(tab.query.isEmpty || tab.isExecuting)

            Button(action: {
                if tab.isExecuting {
                    tab.cancelQuery()
                } else {
                    onExecute()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: tab.isExecuting ? "stop.fill" : "play.fill")
                    Text(tab.isExecuting ? "Stop" : "Run")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(tab.isExecuting ? Color.red : (tab.query.isEmpty ? Color.blue.opacity(0.3) : Color.blue))
                )
            }
            .disabled(tab.query.isEmpty && !tab.isExecuting)
        }
    }
}
