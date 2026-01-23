import SwiftUI

struct ConnectionsListView: View {
    @EnvironmentObject var dbService: DatabaseService
    @Binding var selectedTab: Int
    @State private var showingAddConnection = false
    @State private var editingConnection: DatabaseConnection?
    @State private var searchText = ""
    @State private var selectedConnection: DatabaseConnection?
    @State private var isConnecting = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        if horizontalSizeClass == .compact {
            // iPhone: single column
            return [GridItem(.flexible(), spacing: 16)]
        } else {
            // iPad: adaptive grid
            return [GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 20)]
        }
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                // Background subtle gradient
                LinearGradient(colors: [Color.blue.opacity(0.05), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: isCompact ? 20 : 32) {
                        // Header & Search
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Connections")
                                .font(.system(size: isCompact ? 28 : 34, weight: .bold))
                                .foregroundColor(.primary)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search connections...", text: $searchText)
                                    .textFieldStyle(.plain)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.1), lineWidth: 1))
                        }
                        .padding(.horizontal, isCompact ? 16 : 20)
                        .padding(.top, isCompact ? 12 : 20)

                        // Tiles Grid
                        if dbService.savedConnections.isEmpty {
                            emptyStateView
                        } else {
                            LazyVGrid(columns: columns, spacing: isCompact ? 16 : 20) {
                                ForEach(filteredConnections) { connection in
                                    let isActive = dbService.activeWorkspaces.contains(where: { $0.connection.id == connection.id })
                                    ConnectionTile(
                                        connection: connection,
                                        isActive: isActive,
                                        isConnecting: isConnecting && selectedConnection?.id == connection.id,
                                        isCompact: isCompact,
                                        onConnect: { connectToConnection(connection) },
                                        onEdit: { editingConnection = $0 },
                                        onDelete: dbService.deleteConnection,
                                        onToggleFavorite: dbService.toggleFavorite
                                    )
                                }

                                // "Add New" Tile
                                Button(action: { showingAddConnection = true }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: isCompact ? 28 : 32))
                                            .foregroundColor(.blue)

                                        Text("New Connection")
                                            .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: isCompact ? 120 : 200)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(isCompact ? 16 : 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: isCompact ? 16 : 24)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                            .foregroundColor(.blue.opacity(0.3))
                                    )
                                }
                            }
                            .padding(.horizontal, isCompact ? 16 : 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddConnection = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddConnection) {
                ConnectionWizardView(onSave: { connection in
                    dbService.saveConnection(connection)
                    showingAddConnection = false
                })
                .environmentObject(dbService)
            }
            .sheet(item: $editingConnection) { connection in
                EditConnectionView(connection: connection, onSave: { updated in
                    dbService.saveConnection(updated)
                    editingConnection = nil
                })
                .environmentObject(dbService)
            }
        }
    }

    private var filteredConnections: [DatabaseConnection] {
        dbService.savedConnections.filter { connection in
            searchText.isEmpty ||
            connection.name.localizedCaseInsensitiveContains(searchText) ||
            connection.host.localizedCaseInsensitiveContains(searchText) ||
            connection.database.localizedCaseInsensitiveContains(searchText)
        }.sorted { (c1, c2) in
            if c1.isFavorite != c2.isFavorite { return c1.isFavorite }
            return c1.name < c2.name
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "cylinder.fill")
                .font(.system(size: 80))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Ready to dive in?")
                    .font(.title2)
                    .bold()
                Text("Create your first database connection to start exploring your data with style.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: { showingAddConnection = true }) {
                Text("Add First Connection")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.blue))
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
            }
            Spacer()
        }
        .frame(height: 500)
    }

    private func connectToConnection(_ connection: DatabaseConnection) {
        selectedConnection = connection
        isConnecting = true

        Task {
            do {
                guard let fullConnection = dbService.getConnectionWithPassword(id: connection.id) else {
                    return
                }

                try await dbService.connect(to: fullConnection)
                await MainActor.run {
                    isConnecting = false
                    selectedTab = 1
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                }
            }
        }
    }
}

struct ConnectionTile: View {
    let connection: DatabaseConnection
    let isActive: Bool
    let isConnecting: Bool
    var isCompact: Bool = false
    let onConnect: () -> Void
    let onEdit: (DatabaseConnection) -> Void
    let onDelete: (DatabaseConnection) -> Void
    let onToggleFavorite: (DatabaseConnection) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onConnect) {
            VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(connection.type.color.opacity(0.1))
                            .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

                        Image(systemName: connection.type.icon)
                            .foregroundColor(connection.type.color)
                            .font(.system(size: isCompact ? 16 : 20, weight: .semibold))
                    }

                    if isCompact {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connection.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text(connection.host)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Text(connection.type.rawValue.uppercased())
                            .font(.system(size: isCompact ? 9 : 10, weight: .black))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)

                        if connection.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: isCompact ? 10 : 12))
                        }

                        if isConnecting {
                            ProgressView().scaleEffect(0.7)
                        }
                    }
                }

                if !isCompact {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(connection.host)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }

                    Text(connection.database)
                        .font(.system(size: isCompact ? 10 : 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                        .lineLimit(1)

                    Spacer()

                    if isCompact {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .padding(isCompact ? 14 : 20)
            .background(.ultraThinMaterial)
            .cornerRadius(isCompact ? 16 : 24)
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 16 : 24)
                    .stroke(Color.primary.opacity(isHovering ? 0.2 : 0.05), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHovering ? 0.1 : 0.03), radius: isCompact ? 4 : 10, y: isCompact ? 2 : 5)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onConnect) {
                Label("Connect", systemImage: "play.fill")
            }

            Button(action: { onToggleFavorite(connection) }) {
                Label(
                    connection.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: connection.isFavorite ? "star.slash" : "star.fill"
                )
            }

            Button(action: { onEdit(connection) }) {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: { onDelete(connection) }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct EditConnectionView: View {
    let connection: DatabaseConnection
    let onSave: (DatabaseConnection) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var name: String
    @State private var type: DatabaseType
    @State private var host: String
    @State private var port: String
    @State private var database: String
    @State private var username: String
    @State private var password: String

    init(connection: DatabaseConnection, onSave: @escaping (DatabaseConnection) -> Void) {
        self.connection = connection
        self.onSave = onSave
        _name = State(initialValue: connection.name)
        _type = State(initialValue: connection.type)
        _host = State(initialValue: connection.host)
        _port = State(initialValue: String(connection.port))
        _database = State(initialValue: connection.database)
        _username = State(initialValue: connection.username)
        _password = State(initialValue: connection.password)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Connection Details")) {
                    TextField("Connection Name", text: $name)
                    TextField("Host", text: $host)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Database", text: $database)
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
            }
            .navigationTitle("Edit Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updated = connection
                        updated.name = name
                        updated.host = host
                        updated.port = Int(port) ?? type.defaultPort
                        updated.database = database
                        updated.username = username
                        updated.password = password
                        onSave(updated)
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
