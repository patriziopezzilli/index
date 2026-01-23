import SwiftUI

struct SavedQueriesView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    @State private var showingSaveDialog = false
    @State private var selectedQuery: SavedQuery?
    @Binding var loadQuery: String?

    var filteredQueries: [SavedQuery] {
        var queries = databaseService.savedQueries

        if selectedCategory != "All" {
            queries = queries.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            queries = queries.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.query.localizedCaseInsensitiveContains(searchText)
            }
        }

        return queries.sorted { $0.lastModified > $1.lastModified }
    }

    var categories: [String] {
        ["All"] + databaseService.categories
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    BrowserSearchBar(text: $searchText)
                        .padding()

                    CategoryPicker(categories: categories, selected: $selectedCategory)
                        .padding(.horizontal)

                    if filteredQueries.isEmpty {
                        EmptyQueriesView(hasQueries: !databaseService.savedQueries.isEmpty)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredQueries) { query in
                                    SavedQueryRow(
                                        query: query,
                                        onTap: {
                                            selectedQuery = query
                                        },
                                        onLoad: {
                                            loadQuery = query.query
                                        },
                                        onDelete: {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                databaseService.deleteQuery(query)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Saved Queries")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedQuery) { query in
                SavedQueryDetailView(query: query, loadQuery: $loadQuery)
            }
        }
    }
}

struct CategoryPicker: View {
    let categories: [String]
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = category
                        }
                    }) {
                        Text(category)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selected == category ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selected == category ? Color.blue : Color(.secondarySystemBackground))
                            )
                    }
                }
            }
        }
    }
}

struct EmptyQueriesView: View {
    let hasQueries: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: hasQueries ? "magnifyingglass" : "tray")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.gray.opacity(0.4))

            VStack(spacing: 12) {
                Text(hasQueries ? "No Results" : "No Saved Queries")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(hasQueries ? "Try adjusting your search or filter" : "Save your frequently used queries for quick access")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }
}

struct SavedQueryRow: View {
    let query: SavedQuery
    let onTap: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: query.categoryIcon)
                            .font(.system(size: 18))
                            .foregroundColor(categoryColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(query.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(query.category)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(query.lastModified, style: .relative)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Button(action: onLoad) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.left")
                                Text("Load")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Text(query.query)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(12)
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
            .contextMenu {
                Button(action: onLoad) {
                    Label("Load Query", systemImage: "arrow.down.left")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var categoryColor: Color {
        switch query.categoryColor {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }
}

struct SavedQueryDetailView: View {
    let query: SavedQuery
    @Binding var loadQuery: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(categoryColor.opacity(0.15))
                                .frame(width: 60, height: 60)

                            Image(systemName: query.categoryIcon)
                                .font(.system(size: 28))
                                .foregroundColor(categoryColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(query.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text(query.category)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Query")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(query.query)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }

                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text(query.createdAt, style: .date)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Modified")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Text(query.lastModified, style: .relative)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }

                    Button(action: {
                        loadQuery = query.query
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.left")
                            Text("Load in Editor")
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
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("Query Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: {
                        databaseService.deleteQuery(query)
                        dismiss()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private var categoryColor: Color {
        switch query.categoryColor {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
    }
}
