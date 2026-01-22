import SwiftUI

struct SQLEditorView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @StateObject private var tabManager = QueryTabManager()
    @State private var showingSaveDialog = false
    @State private var showingSchemaSheet = false
    @State private var showingSavedQueriesSheet = false
    @State private var schemaInsertText: String?
    @State private var savedQueryLoadText: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

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
                        }
                    }
                }
            }
            .navigationTitle("SQL Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showingSchemaSheet = true }) {
                            Label("Schema Browser", systemImage: "list.bullet.rectangle")
                        }

                        Button(action: { showingSavedQueriesSheet = true }) {
                            Label("Saved Queries", systemImage: "folder")
                        }

                        Divider()

                        Button(action: { showingSaveDialog = true }) {
                            Label("Save Query", systemImage: "square.and.arrow.down")
                        }
                        .disabled(tabManager.currentTab?.query.isEmpty ?? true)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if let tab = tabManager.currentTab {
                            executeQuery(for: tab)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                            Text("Run")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.white)
                        )
                    }
                    .disabled(tabManager.currentTab?.query.isEmpty ?? true || tabManager.currentTab?.isExecuting ?? false)
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
            .onChange(of: schemaInsertText) { newValue in
                if let text = newValue, let tab = tabManager.currentTab {
                    tab.query += (tab.query.isEmpty ? "" : "\n") + text
                    schemaInsertText = nil
                }
            }
            .onChange(of: savedQueryLoadText) { newValue in
                if let text = newValue {
                    tabManager.addTab(withQuery: text)
                    savedQueryLoadText = nil
                }
            }
        }
    }

    private func executeQuery(for tab: QueryTab) {
        tab.isExecuting = true

        Task {
            let result = await databaseService.executeQuery(tab.query)

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    tab.result = result
                    tab.isExecuting = false
                }
            }
        }
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
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
            }
        }
        .frame(height: 44)
        .background(Color.white.opacity(0.05))
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
                            .tint(.white)
                    }

                    Text(tab.name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 16, height: 16)
            }
            .padding(.trailing, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }
}

struct TabContentView: View {
    @ObservedObject var tab: QueryTab
    @ObservedObject var databaseService: DatabaseService
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SQLEditorTextView(
                text: Binding(
                    get: { tab.query },
                    set: { newValue in
                        tab.query = newValue
                        tab.updateName(from: newValue)
                    }
                ),
                isEditorFocused: $isEditorFocused
            )
            .frame(height: tab.result != nil ? 250 : nil)

            if let result = tab.result {
                Divider()
                    .background(Color.white.opacity(0.1))

                QueryResultView(result: result)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct SQLEditorTextView: View {
    @Binding var text: String
    var isEditorFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding()
                .focused(isEditorFocused)

            if text.isEmpty {
                Text("Write your SQL query here...\n\nExample:\nSELECT * FROM users\nWHERE created_at > '2024-01-01';")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding()
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.white.opacity(0.05))
    }
}

struct NoConnectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text("No Active Connection")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Connect to a database to start executing queries")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
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
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Query Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            TextField("My Query", text: $name)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.1))
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

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
                                .foregroundColor(.white.opacity(0.7))

                            Text(query)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                        }

                        Button(action: {
                            onSave(name, category)
                        }) {
                            Text("Save Query")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(name.isEmpty ? Color.white.opacity(0.3) : .white)
                                )
                        }
                        .disabled(name.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Save Query")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
