import SwiftUI

struct ConnectionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var databaseService: DatabaseService
    @State private var showingAddConnection = false
    @State private var selectedConnection: DatabaseConnection?
    @State private var isConnecting = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 16) {
                        if appState.connections.isEmpty {
                            EmptyConnectionsView(showingAddConnection: $showingAddConnection)
                        } else {
                            ForEach(appState.connections) { connection in
                                ConnectionCard(
                                    connection: connection,
                                    isConnected: databaseService.currentConnection?.id == connection.id,
                                    onConnect: {
                                        connectToDatabase(connection)
                                    },
                                    onDelete: {
                                        deleteConnection(connection)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }

                if isConnecting {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddConnection = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddConnection) {
                AddConnectionView()
            }
        }
    }

    private func connectToDatabase(_ connection: DatabaseConnection) {
        isConnecting = true

        Task {
            do {
                try await databaseService.connect(to: connection)
                await MainActor.run {
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                }
            }
        }
    }

    private func deleteConnection(_ connection: DatabaseConnection) {
        if let index = appState.connections.firstIndex(where: { $0.id == connection.id }) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appState.connections.remove(at: index)
                appState.saveConnections()

                if databaseService.currentConnection?.id == connection.id {
                    databaseService.disconnect()
                }
            }
        }
    }
}

struct EmptyConnectionsView: View {
    @Binding var showingAddConnection: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text("No Connections Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Add your first database connection to get started")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                showingAddConnection = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Connection")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 200, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                )
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct ConnectionCard: View {
    let connection: DatabaseConnection
    let isConnected: Bool
    let onConnect: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(connection.type.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: connection.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(connection.type.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Text(connection.type.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(connection.type.color)
                }

                Spacer()

                if isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)

                        Text("Connected")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
                }
            }

            Text(connection.displayInfo)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 12) {
                Button(action: onConnect) {
                    HStack(spacing: 6) {
                        Image(systemName: isConnected ? "checkmark.circle.fill" : "bolt.fill")
                        Text(isConnected ? "Connected" : "Connect")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isConnected ? .green : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isConnected ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    )
                }
                .disabled(isConnected)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.2))
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}
