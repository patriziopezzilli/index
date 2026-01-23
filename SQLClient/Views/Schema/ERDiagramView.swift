import SwiftUI

struct ERDiagramView: View {
    let schema: DatabaseSchema
    @Environment(\.dismiss) var dismiss
    @State private var generatedImage: UIImage?
    @State private var showingShareSheet = false
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView([.horizontal, .vertical]) {
                    ERDiagramContent(schema: schema)
                        .padding(40)
                }
            }
            .navigationTitle("ER Diagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportDiagram) {
                        if isGenerating {
                            ProgressView()
                                .tint(.blue)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .disabled(isGenerating)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let image = generatedImage {
                    ShareSheet(items: [image])
                }
            }
        }
    }

    private func exportDiagram() {
        isGenerating = true

        DispatchQueue.global(qos: .userInitiated).async {
            let renderer = ImageRenderer(content: ERDiagramContent(schema: schema).padding(40))
            renderer.scale = 3.0

            if let image = renderer.uiImage {
                DispatchQueue.main.async {
                    self.generatedImage = image
                    self.isGenerating = false
                    self.showingShareSheet = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isGenerating = false
                }
            }
        }
    }
}

struct ERDiagramContent: View {
    let schema: DatabaseSchema

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            HStack {
                Image(systemName: "diagram.split.3x3")
                    .font(.title)
                    .foregroundColor(.blue)

                Text(schema.name.isEmpty ? "Database Schema" : schema.name)
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Text("\(schema.tables.count) tables")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                    )
            }

            let columns = arrangeInColumns(schema.tables, columnCount: 3)

            HStack(alignment: .top, spacing: 40) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, columnTables in
                    VStack(alignment: .leading, spacing: 30) {
                        ForEach(columnTables) { table in
                            ERTableBox(table: table)
                        }
                    }
                }
            }
        }
    }

    private func arrangeInColumns(_ tables: [TableSchema], columnCount: Int) -> [[TableSchema]] {
        var columns: [[TableSchema]] = Array(repeating: [], count: columnCount)

        for (index, table) in tables.enumerated() {
            columns[index % columnCount].append(table)
        }

        return columns
    }
}

struct ERTableBox: View {
    let table: TableSchema

    var tableColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan]
        let hash = abs(table.name.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(tableColor)

                Text(table.name)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(table.rowCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(tableColor.opacity(0.15))

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(table.columns.prefix(10).enumerated()), id: \.element.id) { index, column in
                    HStack(spacing: 8) {
                        Image(systemName: column.typeIcon)
                            .font(.caption)
                            .foregroundColor(tableColor.opacity(0.7))
                            .frame(width: 16)

                        Text(column.name)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(column.type)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)

                        if column.isPrimaryKey {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }

                        if !column.nullable {
                            Text("*")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    if index < min(table.columns.count, 10) - 1 {
                        Divider()
                            .padding(.leading, 36)
                    }
                }

                if table.columns.count > 10 {
                    HStack {
                        Spacer()
                        Text("+ \(table.columns.count - 10) more columns")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 300)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(tableColor.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: tableColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
