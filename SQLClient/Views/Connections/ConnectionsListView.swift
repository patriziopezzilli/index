import SwiftUI

struct ConnectionsListView: View {
    @EnvironmentObject var dbService: DatabaseService
    @State private var showingAddConnection = false
    @State private var editingConnection: DatabaseConnection?
    @State private var searchText = ""
    @State private var selectedConnection: DatabaseConnection?
    @State private var isConnecting = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search connections...", text: $searchText)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Favorites Section
                        if !dbService.favoriteConnections.isEmpty {
                            ConnectionSection(
                                title: "Favorites",
                                icon: "star.fill",
                                connections: filteredFavorites,
                                onConnect: connectToConnection,
                                onEdit: { editingConnection = $0 },
                                onDelete: dbService.deleteConnection,
                                onToggleFavorite: dbService.toggleFavorite
                            )
                        }

                        // Recent Section
                        if !dbService.recentConnections.isEmpty {
                            ConnectionSection(
                                title: "Recent",
                                icon: "clock.fill",
                                connections: filteredRecent,
                                onConnect: connectToConnection,
                                onEdit: { editingConnection = $0 },
                                onDelete: dbService.deleteConnection,
                                onToggleFavorite: dbService.toggleFavorite
                            )
                        }

                        // All Connections
                        ConnectionSection(
                            title: "All Connections",
                            icon: "cylinder.fill",
                            connections: filteredConnections,
                            onConnect: connectToConnection,
                            onEdit: { editingConnection = $0 },
                            onDelete: dbService.deleteConnection,
                            onToggleFavorite: dbService.toggleFavorite
                        )

                        if dbService.savedConnections.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "cylinder")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)

                                Text("No Saved Connections")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Text("Create your first connection to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)

                                Button(action: { showingAddConnection = true }) {
                                    Label("Add Connection", systemImage: "plus.circle.fill")
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                                .padding(.top)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Connections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddConnection = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddConnection) {
                AddConnectionView(onSave: { connection in
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
        .navigationViewStyle(.stack)
    }

    private var filteredConnections: [DatabaseConnection] {
        if searchText.isEmpty {
            return dbService.savedConnections.sorted { $0.name < $1.name }
        }
        return dbService.savedConnections.filter { connection in
            connection.name.localizedCaseInsensitiveContains(searchText) ||
            connection.host.localizedCaseInsensitiveContains(searchText) ||
            connection.database.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredFavorites: [DatabaseConnection] {
        dbService.favoriteConnections.filter { connection in
            searchText.isEmpty ||
            connection.name.localizedCaseInsensitiveContains(searchText) ||
            connection.host.localizedCaseInsensitiveContains(searchText) ||
            connection.database.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredRecent: [DatabaseConnection] {
        dbService.recentConnections.filter { connection in
            searchText.isEmpty ||
            connection.name.localizedCaseInsensitiveContains(searchText) ||
            connection.host.localizedCaseInsensitiveContains(searchText) ||
            connection.database.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func connectToConnection(_ connection: DatabaseConnection) {
        selectedConnection = connection
        isConnecting = true

        Task {
            do {
                // Get full connection with password from keychain
                guard let fullConnection = dbService.getConnectionWithPassword(id: connection.id) else {
                    return
                }

                try await dbService.connect(to: fullConnection)
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    // Show error alert
                }
            }
        }
    }
}

struct ConnectionSection: View {
    let title: String
    let icon: String
    let connections: [DatabaseConnection]
    let onConnect: (DatabaseConnection) -> Void
    let onEdit: (DatabaseConnection) -> Void
    let onDelete: (DatabaseConnection) -> Void
    let onToggleFavorite: (DatabaseConnection) -> Void

    var body: some View {
        if !connections.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(connections) { connection in
                        ConnectionRow(
                            connection: connection,
                            onConnect: { onConnect(connection) },
                            onEdit: { onEdit(connection) },
                            onDelete: { onDelete(connection) },
                            onToggleFavorite: { onToggleFavorite(connection) }
                        )
                    }
                }
            }
        }
    }
}

struct ConnectionRow: View {
    let connection: DatabaseConnection
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(connection.type.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: connection.type.icon)
                        .foregroundColor(connection.type.color)
                        .font(.system(size: 24))
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(connection.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        if connection.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }

                    Text(connection.displayInfo)
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    HStack(spacing: 12) {
                        Label(connection.type.rawValue, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.gray)

                        if let lastUsed = connection.lastUsed {
                            Label(formatDate(lastUsed), systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .contextMenu {
            Button(action: onConnect) {
                Label("Connect", systemImage: "play.fill")
            }

            Button(action: onToggleFavorite) {
                Label(
                    connection.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: connection.isFavorite ? "star.slash" : "star.fill"
                )
            }

            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Edit Connection View
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
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                Form {
                    Section(header: Text("Connection Details").foregroundColor(.gray)) {
                        TextField("Connection Name", text: $name)
                        TextField("Host", text: $host)
                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)
                        TextField("Database", text: $database)
                        TextField("Username", text: $username)
                        SecureField("Password", text: $password)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
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
                    .foregroundColor(.blue)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
