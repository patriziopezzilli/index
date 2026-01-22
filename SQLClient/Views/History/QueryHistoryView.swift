import SwiftUI

struct QueryHistoryView: View {
    @EnvironmentObject var dbService: DatabaseService
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    @State private var selectedQuery: QueryHistory?
    @State private var showingQueryDetail = false
    let onRerun: (String) -> Void

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case successful = "Successful"
        case failed = "Failed"

        var icon: String {
            switch self {
            case .all:
                return "clock.fill"
            case .successful:
                return "checkmark.circle.fill"
            case .failed:
                return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .all:
                return .blue
            case .successful:
                return .green
            case .failed:
                return .red
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search queries...", text: $searchText)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding()

                    // Filter Options
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                FilterButton(
                                    option: option,
                                    isSelected: filterOption == option,
                                    count: getCount(for: option)
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        filterOption = option
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)

                    // History List
                    if filteredHistory.isEmpty {
                        EmptyHistoryView(filterOption: filterOption)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredHistory) { item in
                                    QueryHistoryRow(
                                        item: item,
                                        onRerun: {
                                            onRerun(item.query)
                                        },
                                        onShowDetail: {
                                            selectedQuery = item
                                            showingQueryDetail = true
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Query History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: clearHistory) {
                            Label("Clear All History", systemImage: "trash")
                        }

                        Button(action: exportHistory) {
                            Label("Export History", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingQueryDetail) {
                if let query = selectedQuery {
                    QueryDetailView(
                        queryHistory: query,
                        onRerun: {
                            onRerun(query.query)
                            showingQueryDetail = false
                        }
                    )
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var filteredHistory: [QueryHistory] {
        var history = dbService.queryHistory

        // Apply filter
        switch filterOption {
        case .all:
            break
        case .successful:
            history = history.filter { $0.success }
        case .failed:
            history = history.filter { !$0.success }
        }

        // Apply search
        if !searchText.isEmpty {
            history = history.filter {
                $0.query.localizedCaseInsensitiveContains(searchText)
            }
        }

        return history
    }

    private func getCount(for option: FilterOption) -> Int {
        switch option {
        case .all:
            return dbService.queryHistory.count
        case .successful:
            return dbService.queryHistory.filter { $0.success }.count
        case .failed:
            return dbService.queryHistory.filter { !$0.success }.count
        }
    }

    private func clearHistory() {
        dbService.queryHistory.removeAll()
    }

    private func exportHistory() {
        // TODO: Implement export functionality
    }
}

struct FilterButton: View {
    let option: QueryHistoryView.FilterOption
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: option.icon)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: .semibold))

                    Text("\(count)")
                        .font(.caption2)
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? option.color.opacity(0.3) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? option.color : Color.clear, lineWidth: 1)
            )
        }
    }
}

struct QueryHistoryRow: View {
    let item: QueryHistory
    let onRerun: () -> Void
    let onShowDetail: () -> Void

    var body: some View {
        Button(action: onShowDetail) {
            HStack(spacing: 12) {
                // Status indicator
                ZStack {
                    Circle()
                        .fill(item.success ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: item.success ? "checkmark" : "xmark")
                        .foregroundColor(item.success ? .green : .red)
                        .font(.system(size: 16, weight: .bold))
                }

                // Query info
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.query.prefix(80) + (item.query.count > 80 ? "..." : ""))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Label(formatDate(item.timestamp), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Label(String(format: "%.2fs", item.executionTime), systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Re-run button
                Button(action: onRerun) {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 24))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onRerun) {
                Label("Re-run Query", systemImage: "play.fill")
            }

            Button(action: copyQuery) {
                Label("Copy Query", systemImage: "doc.on.doc")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func copyQuery() {
        UIPasteboard.general.string = item.query
    }
}

struct EmptyHistoryView: View {
    let filterOption: QueryHistoryView.FilterOption

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: filterOption.icon)
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No \(filterOption.rawValue) Queries")
                .font(.headline)
                .foregroundColor(.white)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var emptyMessage: String {
        switch filterOption {
        case .all:
            return "Your query history will appear here once you start executing queries"
        case .successful:
            return "No successful queries yet"
        case .failed:
            return "No failed queries - that's great!"
        }
    }
}

struct QueryDetailView: View {
    let queryHistory: QueryHistory
    let onRerun: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Status
                        HStack {
                            Image(systemName: queryHistory.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(queryHistory.success ? .green : .red)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(queryHistory.success ? "Successful" : "Failed")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text(formatFullDate(queryHistory.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Text(String(format: "%.2fs", queryHistory.executionTime))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)

                        // Query
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Query")
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(queryHistory.query)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                        }

                        // Actions
                        VStack(spacing: 12) {
                            Button(action: onRerun) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Re-run Query")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }

                            Button(action: copyQuery) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Query")
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Query Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func copyQuery() {
        UIPasteboard.general.string = queryHistory.query
    }
}
