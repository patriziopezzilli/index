import SwiftUI

// MARK: - Main Sidebar View

struct SchemaSidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dbService: DatabaseService
    @ObservedObject var workspace: WorkspaceTab
    let onImport: () -> Void
    let onBackup: () -> Void

    @State private var searchText = ""
    @State private var selectedCategory: SchemaCategory = .tables

    private var isCompact: Bool {
        appState.displayDensity == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            // Connection Header
            SidebarConnectionHeader(workspace: workspace, isCompact: isCompact)

            // Quick Actions Bar
            SidebarQuickActionsBar(
                workspace: workspace,
                onImport: onImport,
                onBackup: onBackup,
                isCompact: isCompact
            )

            // Search Bar
            SidebarSearchBar(searchText: $searchText, isCompact: isCompact)

            // Category Selector
            SidebarCategorySelector(
                selectedCategory: $selectedCategory,
                schema: workspace.schema,
                isCompact: isCompact
            )

            // Object List
            if let schema = workspace.schema {
                SidebarObjectListView(
                    schema: schema,
                    category: selectedCategory,
                    searchText: searchText,
                    workspace: workspace,
                    isCompact: isCompact
                )
            } else {
                SidebarLoadingView()
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Connection Header

struct SidebarConnectionHeader: View {
    @ObservedObject var workspace: WorkspaceTab
    let isCompact: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Database Icon with status
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: databaseIcon)
                    .font(.system(size: isCompact ? 20 : 24, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.connection.name)
                    .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(workspace.schema?.name ?? "Loading...")
                    .font(.system(size: isCompact ? 10 : 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Stats badge
            if let schema = workspace.schema {
                SidebarStatsBadge(count: schema.tables.count, label: "tables", isCompact: isCompact)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 12 : 16)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var databaseIcon: String {
        switch workspace.connection.type {
        case .postgresql: return "cylinder.split.1x2"
        case .mysql: return "cylinder"
        case .sqlite: return "doc.badge.gearshape"
        }
    }
}

struct SidebarStatsBadge: View {
    let count: Int
    let label: String
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("\(count)")
                .font(.system(size: isCompact ? 14 : 16, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
            Text(label)
                .font(.system(size: isCompact ? 8 : 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Quick Actions Bar

struct SidebarQuickActionsBar: View {
    @ObservedObject var workspace: WorkspaceTab
    let onImport: () -> Void
    let onBackup: () -> Void
    let isCompact: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isCompact ? 8 : 12) {
                SidebarQuickActionButton(
                    icon: "terminal.fill",
                    label: "New Query",
                    color: .blue,
                    isCompact: isCompact
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        let newTab = WorkspaceSubTab(name: "SQL Worksheet", type: .editor)
                        workspace.subTabs.append(newTab)
                        workspace.selectedSubTabId = newTab.id
                    }
                }

                SidebarQuickActionButton(
                    icon: "rectangle.3.group.bubble.left.fill",
                    label: "ER Model",
                    color: .purple,
                    isCompact: isCompact
                ) {
                    workspace.openERModel()
                }

                SidebarQuickActionButton(
                    icon: "square.and.arrow.down.fill",
                    label: "Import",
                    color: .green,
                    isCompact: isCompact,
                    action: onImport
                )

                SidebarQuickActionButton(
                    icon: "archivebox.fill",
                    label: "Backup",
                    color: .orange,
                    isCompact: isCompact,
                    action: onBackup
                )
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, isCompact ? 8 : 12)
        .background(Color(.secondarySystemBackground).opacity(0.3))
    }
}

struct SidebarQuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let isCompact: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: isCompact ? 4 : 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

                    Image(systemName: icon)
                        .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.system(size: isCompact ? 9 : 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Search Bar

struct SidebarSearchBar: View {
    @Binding var searchText: String
    let isCompact: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isCompact ? 13 : 14, weight: .medium))
                .foregroundColor(isFocused ? .blue : .secondary)

            TextField("Search tables, views...", text: $searchText)
                .font(.system(size: isCompact ? 13 : 14))
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isCompact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Category Selector

enum SchemaCategory: String, CaseIterable {
    case tables = "Tables"
    case views = "Views"
    case functions = "Functions"
    case more = "More"

    var icon: String {
        switch self {
        case .tables: return "tablecells"
        case .views: return "eye"
        case .functions: return "function"
        case .more: return "ellipsis"
        }
    }
}

struct SidebarCategorySelector: View {
    @Binding var selectedCategory: SchemaCategory
    let schema: DatabaseSchema?
    let isCompact: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SchemaCategory.allCases, id: \.self) { category in
                    SidebarCategoryTab(
                        category: category,
                        count: countFor(category),
                        isSelected: selectedCategory == category,
                        isCompact: isCompact
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private func countFor(_ category: SchemaCategory) -> Int {
        guard let schema = schema else { return 0 }
        switch category {
        case .tables: return schema.tables.count
        case .views: return schema.views.count
        case .functions: return schema.functions.count + schema.procedures.count
        case .more: return schema.sequences.count
        }
    }
}

struct SidebarCategoryTab: View {
    let category: SchemaCategory
    let count: Int
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: isCompact ? 11 : 12, weight: .medium))

                Text(category.rawValue)
                    .font(.system(size: isCompact ? 11 : 12, weight: isSelected ? .semibold : .medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: isCompact ? 9 : 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, isCompact ? 10 : 14)
            .padding(.vertical, isCompact ? 6 : 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Object List

struct SidebarObjectListView: View {
    let schema: DatabaseSchema
    let category: SchemaCategory
    let searchText: String
    @ObservedObject var workspace: WorkspaceTab
    let isCompact: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                switch category {
                case .tables:
                    ForEach(filteredTables, id: \.name) { table in
                        SidebarTableRow(
                            table: table,
                            isSelected: workspace.currentSubTab?.tableContext == table.name,
                            isCompact: isCompact
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                workspace.openTable(table.name)
                            }
                        }
                    }

                case .views:
                    ForEach(filteredViews, id: \.name) { view in
                        SidebarSchemaObjectRow(
                            object: view,
                            icon: "eye",
                            color: .purple,
                            isCompact: isCompact
                        )
                    }

                case .functions:
                    if !schema.functions.isEmpty {
                        SidebarSectionHeader(title: "Functions", count: schema.functions.count)
                        ForEach(filteredFunctions, id: \.name) { function in
                            SidebarSchemaObjectRow(
                                object: function,
                                icon: "f.circle.fill",
                                color: .orange,
                                isCompact: isCompact
                            )
                        }
                    }

                    if !schema.procedures.isEmpty {
                        SidebarSectionHeader(title: "Procedures", count: schema.procedures.count)
                        ForEach(filteredProcedures, id: \.name) { procedure in
                            SidebarSchemaObjectRow(
                                object: procedure,
                                icon: "gearshape.2",
                                color: .green,
                                isCompact: isCompact
                            )
                        }
                    }

                case .more:
                    if !schema.sequences.isEmpty {
                        SidebarSectionHeader(title: "Sequences", count: schema.sequences.count)
                        ForEach(filteredSequences, id: \.name) { sequence in
                            SidebarSchemaObjectRow(
                                object: sequence,
                                icon: "arrow.trianglehead.counterclockwise",
                                color: .cyan,
                                isCompact: isCompact
                            )
                        }
                    }

                    if !schema.indexes.isEmpty {
                        SidebarSectionHeader(title: "Indexes", count: schema.indexes.count)
                        ForEach(filteredIndexes, id: \.name) { index in
                            SidebarSchemaObjectRow(
                                object: index,
                                icon: "list.bullet.indent",
                                color: .indigo,
                                isCompact: isCompact
                            )
                        }
                    }
                }

                // Empty state
                if isCurrentCategoryEmpty {
                    SidebarEmptyStateView(category: category, searchText: searchText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var filteredTables: [TableSchema] {
        schema.tables.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredViews: [SchemaObject] {
        schema.views.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredFunctions: [SchemaObject] {
        schema.functions.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredProcedures: [SchemaObject] {
        schema.procedures.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredSequences: [SchemaObject] {
        schema.sequences.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredIndexes: [SchemaObject] {
        schema.indexes.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var isCurrentCategoryEmpty: Bool {
        switch category {
        case .tables: return filteredTables.isEmpty
        case .views: return filteredViews.isEmpty
        case .functions: return filteredFunctions.isEmpty && filteredProcedures.isEmpty
        case .more: return filteredSequences.isEmpty && filteredIndexes.isEmpty
        }
    }
}

struct SidebarSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .padding(.top, 8)
    }
}

// MARK: - Row Components

struct SidebarTableRow: View {
    let table: TableSchema
    let isSelected: Bool
    let isCompact: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                        .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)

                    Image(systemName: "tablecells")
                        .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .blue)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(table.name)
                        .font(.system(size: isCompact ? 13 : 14, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .blue : .primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(table.columns.count) cols", systemImage: "square.grid.3x3")
                        Label("\(formatRowCount(table.rowCount))", systemImage: "number")
                    }
                    .font(.system(size: isCompact ? 9 : 10))
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Primary key indicator
                if table.columns.contains(where: { $0.isPrimaryKey }) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, isCompact ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color(.secondarySystemBackground) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func formatRowCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

struct SidebarSchemaObjectRow: View {
    let object: SchemaObject
    let icon: String
    let color: Color
    let isCompact: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.1))
                    .frame(width: isCompact ? 28 : 32, height: isCompact ? 28 : 32)

                Image(systemName: icon)
                    .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(object.name)
                    .font(.system(size: isCompact ? 13 : 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(object.type)
                    .font(.system(size: isCompact ? 9 : 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isCompact ? 8 : 10)
    }
}

// MARK: - Empty & Loading States

struct SidebarEmptyStateView: View {
    let category: SchemaCategory
    let searchText: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            Text(searchText.isEmpty ? "No \(category.rawValue.lowercased())" : "No results found")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            if !searchText.isEmpty {
                Text("Try a different search term")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct SidebarLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)

            Text("Loading Schema...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Text("Fetching database structure")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
