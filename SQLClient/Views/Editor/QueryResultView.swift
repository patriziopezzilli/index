import SwiftUI

struct QueryResultView: View {
    let result: QueryResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = result.error {
                ErrorResultView(error: error)
            } else if let rowsAffected = result.rowsAffected {
                AffectedRowsView(rowsAffected: rowsAffected, executionTime: result.executionTime)
            } else if !result.columns.isEmpty {
                TableResultView(columns: result.columns, rows: result.rows, executionTime: result.executionTime)
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
                        .foregroundColor(.white)
                }
                .padding()

                Text(error)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
            }
        }
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
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    Text("\(rowsAffected) row\(rowsAffected == 1 ? "" : "s") affected")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Execution time: \(String(format: "%.2f", executionTime))s")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
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
                    .foregroundColor(.white)

                Text("Execution time: \(String(format: "%.2f", executionTime))s")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TableResultView: View {
    let columns: [String]
    let rows: [[String]]
    let executionTime: TimeInterval
    @State private var showingExportOptions = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(rows.count) row\(rows.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Button(action: { showingExportOptions = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                    )
                }

                Text("Execution time: \(String(format: "%.2f", executionTime))s")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.leading, 12)
            }
            .padding()
            .background(Color.white.opacity(0.05))

            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns, id: \.self) { column in
                            Text(column)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(minWidth: 150, alignment: .leading)
                                .padding()
                                .background(Color.blue.opacity(0.2))
                        }
                    }

                    ForEach(rows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                                Text(rows[rowIndex][colIndex])
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                                    .frame(minWidth: 150, alignment: .leading)
                                    .padding()
                                    .background(rowIndex.isMultiple(of: 2) ? Color.white.opacity(0.03) : Color.clear)
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Export Results", isPresented: $showingExportOptions) {
            Button("Export as CSV") {
                exportAsCSV()
            }

            Button("Export as JSON") {
                exportAsJSON()
            }

            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(
            get: { exportURL.map { ExportItem(url: $0) } },
            set: { exportURL = $0?.url }
        )) { item in
            ShareSheet(items: [item.url])
        }
    }

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
