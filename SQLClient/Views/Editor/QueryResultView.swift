import SwiftUI

struct QueryResultView: View {
    @EnvironmentObject var appState: AppState
    let result: QueryResult
    var onPageChange: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = result.error {
                ErrorResultView(error: error)
            } else if let rowsAffected = result.rowsAffected {
                AffectedRowsView(rowsAffected: rowsAffected, executionTime: result.executionTime)
            } else if !result.columns.isEmpty || (result.rowsAffected == nil && result.rows.isEmpty) {
                if result.rows.isEmpty {
                    NoResultsView(executionTime: result.executionTime)
                } else {
                    TableResultView(
                        columns: result.columns,
                        rows: result.rows,
                        executionTime: result.executionTime,
                        totalRows: result.totalRows,
                        page: result.page,
                        pageSize: result.pageSize,
                        tableName: result.tableName,
                        primaryKeyColumn: result.primaryKeyColumn,
                        onPageChange: onPageChange
                    )
                }
            } else {
                SuccessResultView(executionTime: result.executionTime)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorResultView: View {
    let error: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)

                    Text("Query Failed")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding()

                Text(error)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
            }
        }
        .background(Color(.systemBackground))
    }
}

struct AffectedRowsView: View {
    let rowsAffected: Int
    let executionTime: TimeInterval

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Query Executed Successfully")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                VStack(spacing: 8) {
                    Text("\(rowsAffected) row\(rowsAffected == 1 ? "" : "s") affected")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)

                    Text("Execution time: \(String(format: "%.2f", executionTime))s")
                        .font(.system(size: 14))
                        .foregroundColor(executionTimeColor(executionTime))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private func executionTimeColor(_ time: TimeInterval) -> Color {
        if time < 0.1 { return .green }
        if time < 1.0 { return .orange }
        return .red
    }
}

struct SuccessResultView: View {
    let executionTime: TimeInterval

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Query Executed Successfully")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Execution time: \(String(format: "%.2f", executionTime))s")
                    .font(.system(size: 14))
                    .foregroundColor(executionTimeColor(executionTime))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private func executionTimeColor(_ time: TimeInterval) -> Color {
        if time < 0.1 { return .green }
        if time < 1.0 { return .orange }
        return .red
    }
}

struct NoResultsView: View {
    let executionTime: TimeInterval

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))

                Text("No Data Found")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                VStack(spacing: 8) {
                    Text("The table exists but contains no rows matching the query.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Execution time: \(String(format: "%.2f", executionTime))s")
                        .font(.system(size: 12))
                        .foregroundColor(executionTimeColor(executionTime))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private func executionTimeColor(_ time: TimeInterval) -> Color {
        if time < 0.1 { return .green }
        if time < 1.0 { return .orange }
        return .red
    }
}
struct TableResultView: View {
    @EnvironmentObject var appState: AppState
    let columns: [String]
    let rows: [[String]]
    let executionTime: TimeInterval
    let totalRows: Int?
    let page: Int
    let pageSize: Int
    var tableName: String? = nil
    var primaryKeyColumn: String? = nil
    var onPageChange: ((Int) -> Void)?

    @State private var showingExportOptions = false
    @State private var exportURL: URL?
    @State private var selectedRow: [String]?
    @State private var columnWidths: [String: CGFloat] = [:]
    @State private var editingCell: Int? // row index << 16 | col index
    @State private var editingValue: String = ""
    @State private var showingVisualization = false
    @EnvironmentObject var dbService: DatabaseService

    @Namespace private var editNamespace

    private var fontSize: CGFloat {
        appState.displayDensity == .compact ? 13 : 16
    }
    
    private var headerFontSize: CGFloat {
        appState.displayDensity == .compact ? 12 : 14
    }
    
    private var verticalPadding: CGFloat {
        appState.displayDensity == .compact ? 8 : 14
    }

    private let minColumnWidth: CGFloat = 120
    private let maxColumnWidth: CGFloat = 300

    var body: some View {
        VStack(spacing: 0) {
            // Header Stats & Export
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let total = totalRows {
                        Text("Showing \(rows.count) of \(total) rows")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(rows.count) rows")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    Text(String(format: "%.3fs", executionTime))
                        .font(.system(size: 10))
                        .foregroundColor(executionTimeColor(executionTime))
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { showingVisualization = true }) {
                        Label("Visualize", systemImage: "chart.bar.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)

                    Button(action: { showingExportOptions = true }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(height: 1),
                alignment: .bottom
            )

            // The Grid
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    // Sticky Header Row
                    headerRow
                        .zIndex(1)

                    // Data Rows
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            dataRow(for: rows[rowIndex], index: rowIndex)
                                .onTapGesture {
                                    selectedRow = rows[rowIndex]
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Pagination Controls
            if let total = totalRows, total > pageSize {
                paginationFooter(total: total)
            }
        }
        .sheet(item: Binding(
            get: { selectedRow.map { RowDetailItem(columns: columns, row: $0) } },
            set: { _ in selectedRow = nil }
        )) { item in
            RowInspectorView(item: item)
        }
        .confirmationDialog("Export Results", isPresented: $showingExportOptions) {
            Button("Export as CSV") { exportAsCSV() }
            Button("Export as JSON") { exportAsJSON() }
            Button("Export as SQL Inserts") { exportAsSQLInserts() }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(
            get: { exportURL.map { ExportItem(url: $0) } },
            set: { exportURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $showingVisualization) {
            DataVisualizationView(result: QueryResult(
                columns: columns,
                rows: rows,
                totalRows: totalRows,
                executionTime: executionTime
            ))
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, column in
                let alignment = columnAlignment(at: colIndex)

                Text(column)
                    .font(.system(size: headerFontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(width: columnWidth(for: column), alignment: alignment)
                    .background(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: 1),
                        alignment: .trailing
                    )
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func columnAlignment(at index: Int) -> Alignment {
        guard let firstRow = rows.first, index < firstRow.count else {
            return .leading
        }
        return isNumeric(firstRow[index]) ? .trailing : .leading
    }

    private func dataRow(for row: [String], index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                let isNull = value == "NULL"
                let isEditing = editingCell == (index << 16 | colIndex)
                let alignment = columnAlignment(at: colIndex)

                Group {
                    if isEditing {
                        HStack(spacing: 0) {
                            TextField("", text: $editingValue)
                                .font(.system(size: fontSize, design: .monospaced))
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 11)
                                .background(Color.blue.opacity(0.1))
                                .onSubmit {
                                    saveEdit(row: row, rowIndex: index, colIndex: colIndex)
                                }

                            HStack(spacing: 4) {
                                Button(action: { saveEdit(row: row, rowIndex: index, colIndex: colIndex) }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.plain)

                                Button(action: { editingCell = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)
                        .padding(.horizontal, 4)
                    } else {
                        Text(value)
                            .font(.system(size: fontSize, design: .monospaced))
                            .foregroundColor(isNull ? .secondary.opacity(0.5) : .primary)
                            .italic(isNull)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                if tableName != nil && primaryKeyColumn != nil {
                                    startEditing(row: index, col: colIndex, value: value)
                                }
                            }
                    }
                }
                .frame(width: columnWidth(for: columns[colIndex]), alignment: alignment)
                .background(index.isMultiple(of: 2) ? Color(.secondarySystemBackground).opacity(0.5) : Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(width: 1),
                    alignment: .trailing
                )
            }
        }
    }

    private func startEditing(row: Int, col: Int, value: String) {
        editingCell = (row << 16 | col)
        editingValue = value == "NULL" ? "" : value
    }

    private func saveEdit(row: [String], rowIndex: Int, colIndex: Int) {
        guard let tblName = tableName,
              let pkCol = primaryKeyColumn,
              let pkIndex = columns.firstIndex(of: pkCol) else {
            editingCell = nil
            return
        }
        
        let pkValue = row[pkIndex]
        let colName = columns[colIndex]
        let newValue = editingValue
        
        Task {
            do {
                try await dbService.updateCell(
                    tableName: tblName,
                    columnName: colName,
                    newValue: newValue,
                    primaryKeyColumn: pkCol,
                    primaryKeyValue: pkValue
                )
                // Success: update UI optimistically or wait for refresh
                // For now, let's update the local row data if result is mutable (we'd need a way to reach back to TableDataView)
                // Actually, the user will probably refresh or we could just update the result local to TableResultView if it was state.
            } catch {
                print("Update failed: \(error)")
            }
            await MainActor.run {
                editingCell = nil
            }
        }
    }

    private func paginationFooter(total: Int) -> some View {
        let totalPages = Int(ceil(Double(total) / Double(pageSize)))

        return HStack {
            Text("Page \(page) of \(totalPages)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { onPageChange?(page - 1) }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(page <= 1)

                Button(action: { onPageChange?(page + 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(page >= totalPages)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func columnWidth(for column: String) -> CGFloat {
        // Simple heuristic: based on column name and some content (if we had it easily)
        // For now, let's use a fixed width or base it on name length
        return max(minColumnWidth, min(maxColumnWidth, CGFloat(column.count * 10 + 40)))
    }

    private func isNumeric(_ value: String) -> Bool {
        return Double(value) != nil || Int(value) != nil
    }

    // Existing export functions updated to use current rows
    private func exportAsCSV() {
        var csvString = columns.joined(separator: ",") + "\n"
        for row in rows {
            let escapedRow = row.map { value in
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return value
            }
            csvString += escapedRow.joined(separator: ",") + "\n"
        }
        saveToFile(content: csvString, filename: "export.csv")
    }

    private func exportAsJSON() {
        var jsonArray: [[String: String]] = []
        for row in rows {
            var jsonObject: [String: String] = [:]
            for (index, column) in columns.enumerated() {
                if index < row.count {
                    jsonObject[column] = row[index]
                }
            }
            jsonArray.append(jsonObject)
        }
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            saveToFile(content: jsonString, filename: "export.json")
        }
    }

    private func exportAsSQLInserts() {
        let exportTableName = tableName ?? "query_result"
        let sql = ImportExportService.shared.generateInsertSQL(
            tableName: exportTableName,
            columns: columns,
            rows: rows
        )
        saveToFile(content: sql, filename: "\(exportTableName)_export.sql")
    }

    private func saveToFile(content: String, filename: String) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            exportURL = fileURL
        } catch {
            print("Failed to write file: \(error)")
        }
    }

    private func executionTimeColor(_ time: TimeInterval) -> Color {
        if time < 0.1 { return .green }
        if time < 1.0 { return .orange }
        return .red
    }
}

struct RowDetailItem: Identifiable {
    let id = UUID()
    let columns: [String]
    let row: [String]
}

struct RowInspectorView: View {
    let item: RowDetailItem
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(0..<item.columns.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.columns[index])
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)

                        Text(item.row[index])
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Row Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
