import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var searchText = ""

    var filteredHistory: [QueryHistory] {
        if searchText.isEmpty {
            return databaseService.queryHistory
        } else {
            return databaseService.queryHistory.filter {
                $0.query.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if databaseService.queryHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredHistory) { item in
                                HistoryItemCard(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Query History")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search queries")
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text("No Query History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Your executed queries will appear here")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct HistoryItemCard: View {
    let item: QueryHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(item.success ? .green : .red)
                    .font(.system(size: 16))

                Text(item.timestamp, style: .time)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Text(item.timestamp, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Text("\(String(format: "%.2f", item.executionTime))s")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }

            Text(item.query)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}
