import SwiftUI

struct PerformanceDashboardView: View {
    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Query Statistics
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            Text("Query Statistics")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .padding(.horizontal)

                        VStack(spacing: 0) {
                            PerformanceStatCard(
                                title: "Total Queries",
                                value: "\(databaseService.queryHistory.count)",
                                icon: "number.circle.fill",
                                color: .blue
                            )

                            Divider().padding(.leading, 60)

                            PerformanceStatCard(
                                title: "Successful Queries",
                                value: "\(databaseService.queryHistory.filter { $0.success }.count)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )

                            Divider().padding(.leading, 60)

                            PerformanceStatCard(
                                title: "Failed Queries",
                                value: "\(databaseService.queryHistory.filter { !$0.success }.count)",
                                icon: "xmark.circle.fill",
                                color: .red
                            )

                            Divider().padding(.leading, 60)

                            PerformanceStatCard(
                                title: "Average Execution Time",
                                value: String(format: "%.3fs", averageExecutionTime),
                                icon: "clock.fill",
                                color: .orange
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    // Performance Insights
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Performance Insights")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            if let slowestQuery = slowestQuery {
                                InsightCard(
                                    title: "Slowest Query",
                                    subtitle: String(format: "%.3fs", slowestQuery.executionTime),
                                    detail: slowestQuery.query.prefix(50) + (slowestQuery.query.count > 50 ? "..." : ""),
                                    color: .red
                                )
                            }

                            if let fastestQuery = fastestQuery {
                                InsightCard(
                                    title: "Fastest Query",
                                    subtitle: String(format: "%.3fs", fastestQuery.executionTime),
                                    detail: fastestQuery.query.prefix(50) + (fastestQuery.query.count > 50 ? "..." : ""),
                                    color: .green
                                )
                            }

                            InsightCard(
                                title: "Success Rate",
                                subtitle: String(format: "%.1f%%", successRate),
                                detail: "Queries executed successfully",
                                color: successRate >= 90 ? .green : successRate >= 70 ? .orange : .red
                            )
                        }
                    }

                    // Recent Performance
                    if !databaseService.queryHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.purple)
                                Text("Recent Query Performance")
                                    .font(.system(size: 18, weight: .bold))
                            }
                            .padding(.horizontal)

                            VStack(spacing: 0) {
                                ForEach(databaseService.queryHistory.prefix(10)) { history in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(history.query.prefix(60) + (history.query.count > 60 ? "..." : ""))
                                                .font(.system(size: 14))
                                                .lineLimit(1)

                                            HStack(spacing: 8) {
                                                Text(history.timestamp, style: .time)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)

                                                Text(String(format: "%.3fs", history.executionTime))
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(executionTimeColor(history.executionTime))
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: history.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundColor(history.success ? .green : .red)
                                            .font(.system(size: 16))
                                    }
                                    .padding()

                                    if history.id != databaseService.queryHistory.prefix(10).last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var averageExecutionTime: Double {
        let successfulQueries = databaseService.queryHistory.filter { $0.success }
        guard !successfulQueries.isEmpty else { return 0 }
        return successfulQueries.map { $0.executionTime }.reduce(0, +) / Double(successfulQueries.count)
    }

    private var slowestQuery: QueryHistory? {
        databaseService.queryHistory.filter { $0.success }.max(by: { $0.executionTime < $1.executionTime })
    }

    private var fastestQuery: QueryHistory? {
        databaseService.queryHistory.filter { $0.success }.min(by: { $0.executionTime < $1.executionTime })
    }

    private var successRate: Double {
        guard !databaseService.queryHistory.isEmpty else { return 0 }
        let successful = databaseService.queryHistory.filter { $0.success }.count
        return Double(successful) / Double(databaseService.queryHistory.count) * 100
    }

    private func executionTimeColor(_ time: TimeInterval) -> Color {
        if time < 0.1 { return .green }
        if time < 1.0 { return .orange }
        return .red
    }
}

struct PerformanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            Spacer()
        }
        .padding()
    }
}

struct InsightCard: View {
    let title: String
    let subtitle: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Spacer()

                Text(subtitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }

            Text(detail)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}