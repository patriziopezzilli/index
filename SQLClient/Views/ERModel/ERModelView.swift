import SwiftUI

struct ERModelView: View {
    @ObservedObject var workspace: WorkspaceTab
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingExportOptions = false
    @State private var exportedImage: UIImage?
    @State private var isExporting = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Grid
                Canvas { context, size in
                    let spacing: CGFloat = 40
                    for x in stride(from: 0, to: size.width, by: spacing) {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(path, with: .color(Color.secondary.opacity(0.05)), lineWidth: 1)
                    }
                    for y in stride(from: 0, to: size.height, by: spacing) {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(path, with: .color(Color.secondary.opacity(0.05)), lineWidth: 1)
                    }
                }
                .frame(width: 5000, height: 5000)

                if let schema = workspace.schema {
                    // Relationship Lines
                    RelationshipLinesView(schema: schema, positions: workspace.tablePositions)
                        .frame(width: 5000, height: 5000)

                    // Table Nodes
                    ForEach(schema.tables) { table in
                        TableNodeView(table: table) { newPos in
                            workspace.tablePositions[table.name] = newPos
                        }
                        .position(workspace.tablePositions[table.name] ?? CGPoint(x: 100, y: 100))
                    }
                }
            }
            .offset(x: dragOffset.width + lastOffset.width, y: dragOffset.height + lastOffset.height)
            .scaleEffect(scale)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        lastOffset.width += value.translation.width
                        lastOffset.height += value.translation.height
                        dragOffset = .zero
                    }
            )
            .onAppear {
                if workspace.tablePositions.isEmpty {
                    initializePositions(in: geometry.size)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipped()
        .overlay(alignment: .top) {
            // Floating controls bar
            HStack(spacing: 12) {
                // Export buttons
                Button(action: { exportAsImage(format: .png) }) {
                    Label("PNG", systemImage: "photo.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: { showingExportOptions = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 24)

                // Zoom controls
                HStack(spacing: 8) {
                    Button(action: { scale = max(0.2, scale - 0.1) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(scale * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(width: 44)

                    Button(action: { scale = min(3.0, scale + 0.1) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    withAnimation(.spring()) {
                        scale = 1.0
                        lastOffset = .zero
                    }
                }) {
                    Text("Reset")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, 12)
        }
        .confirmationDialog("Export ER Diagram", isPresented: $showingExportOptions) {
            Button("Save as PNG") {
                exportAsImage(format: .png)
            }
            Button("Save as JPEG") {
                exportAsImage(format: .jpeg)
            }
            Button("Share Image") {
                exportAndShare()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: Binding(
            get: { exportedImage.map { ExportedImageItem(image: $0) } },
            set: { exportedImage = $0?.image }
        )) { item in
            ERImageShareSheet(image: item.image)
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.3)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Generating image...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }
                .ignoresSafeArea()
            }
        }
    }

    private func initializePositions(in size: CGSize) {
        guard let schema = workspace.schema else { return }
        var currentX: CGFloat = 200
        var currentY: CGFloat = 200
        let spacing: CGFloat = 250

        for table in schema.tables {
            workspace.tablePositions[table.name] = CGPoint(x: currentX, y: currentY)
            currentX += spacing
            if currentX > size.width + 1000 {
                currentX = 200
                currentY += spacing + 100
            }
        }
    }

    private func exportAsImage(format: ImageExportFormat) {
        guard let schema = workspace.schema else { return }

        isExporting = true

        Task {
            let image = await generateERImage(schema: schema, positions: workspace.tablePositions)

            await MainActor.run {
                isExporting = false

                if let image = image {
                    saveImageToPhotos(image: image, format: format)
                }
            }
        }
    }

    private func exportAndShare() {
        guard let schema = workspace.schema else { return }

        isExporting = true

        Task {
            let image = await generateERImage(schema: schema, positions: workspace.tablePositions)

            await MainActor.run {
                isExporting = false
                exportedImage = image
            }
        }
    }

    @MainActor
    private func generateERImage(schema: DatabaseSchema, positions: [String: CGPoint]) async -> UIImage? {
        // Calculate bounds
        let bounds = calculateBounds(positions: positions)
        let padding: CGFloat = 100
        let width = bounds.maxX - bounds.minX + padding * 2
        let height = bounds.maxY - bounds.minY + padding * 2

        // Create the exportable view
        let exportView = ERExportView(
            schema: schema,
            positions: positions,
            offsetX: -bounds.minX + padding,
            offsetY: -bounds.minY + padding,
            width: width,
            height: height
        )
        .frame(width: width, height: height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0 // Higher resolution

        return renderer.uiImage
    }

    private func calculateBounds(positions: [String: CGPoint]) -> (minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat) {
        guard !positions.isEmpty else {
            return (0, 0, 800, 600)
        }

        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var maxY: CGFloat = -.infinity

        for pos in positions.values {
            minX = min(minX, pos.x - 100) // Account for node width
            minY = min(minY, pos.y - 100) // Account for node height
            maxX = max(maxX, pos.x + 100)
            maxY = max(maxY, pos.y + 200)
        }

        return (minX, minY, maxX, maxY)
    }

    private func saveImageToPhotos(image: UIImage, format: ImageExportFormat) {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "ER_Diagram_\(workspace.connection.database).\(format.extension)"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            let data: Data?
            switch format {
            case .png:
                data = image.pngData()
            case .jpeg:
                data = image.jpegData(compressionQuality: 0.9)
            }

            if let data = data {
                try data.write(to: fileURL)

                // Save to Photos
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        } catch {
            print("Failed to save image: \(error)")
        }
    }
}

enum ImageExportFormat {
    case png
    case jpeg

    var `extension`: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}

struct ExportedImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Export View (static version for rendering)

struct ERExportView: View {
    let schema: DatabaseSchema
    let positions: [String: CGPoint]
    let offsetX: CGFloat
    let offsetY: CGFloat
    var width: CGFloat = 2000
    var height: CGFloat = 2000

    var body: some View {
        ZStack {
            // Background - simple white, skip grid for ImageRenderer compatibility
            Color.white

            // Relationship Lines using Path instead of Canvas
            ERExportRelationshipLinesPath(schema: schema, positions: adjustedPositions)

            // Table Nodes
            ForEach(schema.tables) { table in
                if let pos = adjustedPositions[table.name] {
                    ERExportTableNode(table: table)
                        .position(pos)
                }
            }

            // Watermark
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Generated by INDEX")
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray.opacity(0.5))
                        .padding(16)
                }
            }
        }
    }

    private var adjustedPositions: [String: CGPoint] {
        var adjusted: [String: CGPoint] = [:]
        for (name, pos) in positions {
            adjusted[name] = CGPoint(x: pos.x + offsetX, y: pos.y + offsetY)
        }
        return adjusted
    }
}

struct ERExportTableNode: View {
    let table: TableSchema

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(.blue)
                Text(table.name)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            // Columns
            VStack(alignment: .leading, spacing: 4) {
                ForEach(table.columns.prefix(10)) { column in
                    HStack(spacing: 8) {
                        Image(systemName: column.isPrimaryKey ? "key.fill" : column.typeIcon)
                            .font(.system(size: 10))
                            .foregroundColor(column.isPrimaryKey ? .yellow : .gray)

                        Text(column.name)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)

                        Spacer()

                        Text(column.type.lowercased())
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }

                if table.columns.count > 10 {
                    Text("+ \(table.columns.count - 10) more...")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
            }
            .padding(12)
        }
        .frame(width: 200)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// Simple grid background using shapes (ImageRenderer compatible)
struct ERExportGridBackground: View {
    let spacing: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Vertical lines
                for x in stride(from: 0, to: geometry.size.width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                // Horizontal lines
                for y in stride(from: 0, to: geometry.size.height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
        }
    }
}

// Relationship lines using Path (ImageRenderer compatible)
struct ERExportRelationshipLinesPath: View {
    let schema: DatabaseSchema
    let positions: [String: CGPoint]

    var body: some View {
        ZStack {
            ForEach(schema.tables) { table in
                if let fromPos = positions[table.name] {
                    ForEach(table.foreignKeys) { fk in
                        if let toPos = positions[fk.targetTable] {
                            RelationshipLine(from: fromPos, to: toPos)
                        }
                    }
                }
            }
        }
    }
}

struct RelationshipLine: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        ZStack {
            // Bezier curve line
            Path { path in
                path.move(to: from)
                let control1 = CGPoint(x: from.x + (to.x - from.x) / 2, y: from.y)
                let control2 = CGPoint(x: from.x + (to.x - from.x) / 2, y: to.y)
                path.addCurve(to: to, control1: control1, control2: control2)
            }
            .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))

            // Arrowhead
            Path { path in
                let angle = atan2(to.y - from.y, to.x - from.x)
                let arrowSize: CGFloat = 8
                path.move(to: to)
                path.addLine(to: CGPoint(x: to.x - arrowSize * cos(angle - .pi/6), y: to.y - arrowSize * sin(angle - .pi/6)))
                path.addLine(to: CGPoint(x: to.x - arrowSize * cos(angle + .pi/6), y: to.y - arrowSize * sin(angle + .pi/6)))
                path.closeSubpath()
            }
            .fill(Color.blue.opacity(0.7))
        }
    }
}

struct ERExportRelationshipLines: View {
    let schema: DatabaseSchema
    let positions: [String: CGPoint]

    var body: some View {
        Canvas { context, size in
            for table in schema.tables {
                guard let fromPos = positions[table.name] else { continue }

                for fk in table.foreignKeys {
                    guard let toPos = positions[fk.targetTable] else { continue }

                    let path = createBezierPath(from: fromPos, to: toPos)
                    context.stroke(path, with: .color(.blue.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4]))

                    // Draw arrowhead
                    drawArrowhead(context: context, from: fromPos, to: toPos)
                }
            }
        }
    }

    private func createBezierPath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        let control1 = CGPoint(x: from.x + (to.x - from.x) / 2, y: from.y)
        let control2 = CGPoint(x: from.x + (to.x - from.x) / 2, y: to.y)
        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }

    private func drawArrowhead(context: GraphicsContext, from: CGPoint, to: CGPoint) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowSize: CGFloat = 8

        var arrowPath = Path()
        arrowPath.move(to: to)
        arrowPath.addLine(to: CGPoint(x: to.x - arrowSize * cos(angle - .pi/6), y: to.y - arrowSize * sin(angle - .pi/6)))
        arrowPath.addLine(to: CGPoint(x: to.x - arrowSize * cos(angle + .pi/6), y: to.y - arrowSize * sin(angle + .pi/6)))
        arrowPath.closeSubpath()

        context.fill(arrowPath, with: .color(.blue.opacity(0.7)))
    }
}

// MARK: - Share Sheet

struct ERImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TableNodeView: View {
    let table: TableSchema
    var onPositionChange: (CGPoint) -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "tablecells")
                    .foregroundColor(.blue)
                Text(table.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            
            Divider()
            
            // Columns
            VStack(alignment: .leading, spacing: 4) {
                ForEach(table.columns.prefix(8)) { column in
                    HStack(spacing: 8) {
                        Image(systemName: column.isPrimaryKey ? "key.fill" : column.typeIcon)
                            .font(.system(size: 10))
                            .foregroundColor(column.isPrimaryKey ? .yellow : .secondary)
                        
                        Text(column.name)
                            .font(.system(size: 12))
                        
                        Spacer()
                        
                        Text(column.type.lowercased())
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                if table.columns.count > 8 {
                    Text("+ \(table.columns.count - 8) more...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(12)
        }
        .frame(width: 200)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(radius: isDragging ? 10 : 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    onPositionChange(value.location)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}

struct RelationshipLinesView: View {
    let schema: DatabaseSchema
    let positions: [String: CGPoint]
    
    var body: some View {
        Canvas { context, size in
            for table in schema.tables {
                guard let fromPos = positions[table.name] else { continue }
                
                for fk in table.foreignKeys {
                    guard let toPos = positions[fk.targetTable] else { continue }
                    
                    let path = createBezierPath(from: fromPos, to: toPos)
                    context.stroke(path, with: .color(.blue.opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
                    
                    // Draw arrowhead at toPos
                    drawArrowhead(context: context, from: fromPos, to: toPos)
                }
            }
        }
    }
    
    private func createBezierPath(from: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        
        // Add some curvature
        let control1 = CGPoint(x: from.x + (to.x - from.x) / 2, y: from.y)
        let control2 = CGPoint(x: from.x + (to.x - from.x) / 2, y: to.y)
        
        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }
    
    private func drawArrowhead(context: GraphicsContext, from: CGPoint, to: CGPoint) {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowSize: CGFloat = 8
        
        var arrowPath = Path()
        arrowPath.move(to: to)
        arrowPath.addLine(to: CGPoint(x: to.x - arrowSize * cos(angle - .pi/6), y: to.y - arrowSize * sin(angle - .pi/6)))
        arrowPath.addLine(to: CGPoint(x: to.x - arrowSize * cos(angle + .pi/6), y: to.y - arrowSize * sin(angle + .pi/6)))
        arrowPath.closeSubpath()
        
        context.fill(arrowPath, with: .color(.blue.opacity(0.6)))
    }
}
