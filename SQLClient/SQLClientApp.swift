import SwiftUI

@main
struct IndexApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

enum DisplayDensity: String, Codable, CaseIterable {
    case compact = "Compact"
    case relaxed = "Relaxed"
}

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var displayDensity: DisplayDensity
    @Published var connections: [DatabaseConnection] = []

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let densityString = UserDefaults.standard.string(forKey: "displayDensity") ?? DisplayDensity.compact.rawValue
        self.displayDensity = DisplayDensity(rawValue: densityString) ?? .compact
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
