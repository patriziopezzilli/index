import SwiftUI
import Charts

enum ChartType: String, CaseIterable {
    case bar = "Bar Chart"
    case line = "Line Chart"
    case pie = "Pie Chart"
    case area = "Area Chart"
}

struct DataVisualizationView: View {
    let result: QueryResult
    @State private var selectedChartType: ChartType = .bar
    @State private var selectedColumn: String = ""
    @State private var valueColumn: String = ""
    @State private var showingExportOptions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chart Type Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            ChartTypeButton(
                                type: type,
                                isSelected: selectedChartType == type,
                                action: { selectedChartType = type }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.secondarySystemBackground))

                // Column Selection
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Category Column")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            Picker("Category", selection: $selectedColumn) {
                                Text("None").tag("")
                                ForEach(result.columns, id: \.self) { column in
                                    Text(column).tag(column)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(height: 30)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Value Column")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)

                            Picker("Value", selection: $valueColumn) {
                                Text("None").tag("")
                                ForEach(result.columns, id: \.self) { column in
                                    Text(column).tag(column)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(height: 30)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Chart Display
                if canShowChart {
                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 16) {
                                chartView
                                    .frame(height: geometry.size.height * 0.7)
                                    .padding(.horizontal)

                                // Data Summary
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Data Summary")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)

                                    HStack(spacing: 20) {
                                        VisualizationStatBox(
                                            title: "Total Rows",
                                            value: "\(result.rows.count)",
                                            color: .blue
                                        )

                                        if let maxValue = maxValue {
                                            VisualizationStatBox(
                                                title: "Max Value",
                                                value: String(format: "%.2f", maxValue),
                                                color: .green
                                            )
                                        }

                                        if let avgValue = averageValue {
                                            VisualizationStatBox(
                                                title: "Average",
                                                value: String(format: "%.2f", avgValue),
                                                color: .orange
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    }
                } else {
                    VStack(spacing: 24) {
                        Spacer()

                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))

                            Text("Select columns to visualize")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Choose a category column and a numeric value column to create charts from your data.")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Data Visualization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportOptions = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingExportOptions) {
                ExportVisualizationView(result: result, chartType: selectedChartType)
            }
        }
    }

    private var canShowChart: Bool {
        !selectedColumn.isEmpty && !valueColumn.isEmpty && selectedColumn != valueColumn
    }

    private var chartData: [ChartDataPoint] {
        result.rows.compactMap { row in
            guard let categoryIndex = result.columns.firstIndex(of: selectedColumn),
                  let valueIndex = result.columns.firstIndex(of: valueColumn),
                  let value = Double(row[valueIndex]) else { return nil }

            return ChartDataPoint(
                category: row[categoryIndex],
                value: value
            )
        }
    }

    private var maxValue: Double? {
        chartData.map { $0.value }.max()
    }

    private var averageValue: Double? {
        let values = chartData.map { $0.value }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    @ViewBuilder
    private var chartView: some View {
        switch selectedChartType {
        case .bar:
            Chart(chartData, id: \.category) { point in
                BarMark(
                    x: .value("Category", point.category),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }

        case .line:
            Chart(chartData, id: \.category) { point in
                LineMark(
                    x: .value("Category", point.category),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue)
                .symbol(.circle)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }

        case .pie:
            Chart(chartData, id: \.category) { point in
                SectorMark(
                    angle: .value("Value", point.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 1
                )
                .foregroundStyle(by: .value("Category", point.category))
            }

        case .area:
            Chart(chartData, id: \.category) { point in
                AreaMark(
                    x: .value("Category", point.category),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(.blue.opacity(0.6))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
}

struct ChartTypeButton: View {
    let type: ChartType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(type.rawValue)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.secondarySystemBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

struct VisualizationStatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ExportVisualizationView: View {
    let result: QueryResult
    let chartType: ChartType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Export Options")) {
                    Button(action: exportAsCSV) {
                        Label("Export Data as CSV", systemImage: "tablecells")
                    }

                    Button(action: exportAsJSON) {
                        Label("Export Data as JSON", systemImage: "curlybraces")
                    }

                    Button(action: exportChartImage) {
                        Label("Export Chart as Image", systemImage: "photo")
                    }
                }

                Section(header: Text("Share")) {
                    Button(action: shareData) {
                        Label("Share Data", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Export")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }

    private func exportAsCSV() {
        let csvContent = ImportExportService.shared.generateCSV(columns: result.columns, rows: result.rows)
        saveToFile(content: csvContent, filename: "chart_data.csv")
    }

    private func exportAsJSON() {
        let jsonContent = ImportExportService.shared.generateJSON(columns: result.columns, rows: result.rows)
        saveToFile(content: jsonContent, filename: "chart_data.json")
    }

    private func exportChartImage() {
        // In a real implementation, you'd capture the chart view as image
        // For now, just show a placeholder
        let placeholder = "Chart image export would be implemented here"
        saveToFile(content: placeholder, filename: "chart.png")
    }

    private func shareData() {
        let shareText = "Data visualization from SQL query results"

        #if os(iOS)
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #elseif os(macOS)
        let sharingService = NSSharingServicePicker(items: [shareText])
        if let window = NSApplication.shared.windows.first {
            sharingService.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
        #endif
    }

    private func saveToFile(content: String, filename: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            // In a real app, you'd present a share sheet or save dialog
            print("File saved to: \(fileURL)")
        } catch {
            print("Failed to save file: \(error)")
        }
    }
}