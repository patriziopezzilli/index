import SwiftUI

@main
struct SQLClientApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var connections: [DatabaseConnection] = []

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        loadConnections()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func loadConnections() {
        if let data = UserDefaults.standard.data(forKey: "savedConnections"),
           let decoded = try? JSONDecoder().decode([DatabaseConnection].self, from: data) {
            connections = decoded
        }
    }

    func saveConnections() {
        if let encoded = try? JSONEncoder().encode(connections) {
            UserDefaults.standard.set(encoded, forKey: "savedConnections")
        }
    }

    func addConnection(_ connection: DatabaseConnection) {
        connections.append(connection)
        saveConnections()
    }

    func deleteConnection(at offsets: IndexSet) {
        connections.remove(atOffsets: offsets)
        saveConnections()
    }
}
