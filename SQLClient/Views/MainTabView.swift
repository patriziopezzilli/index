import SwiftUI

struct MainTabView: View {
    @StateObject private var databaseService = DatabaseService()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConnectionsView()
                .tabItem {
                    Label("Connections", systemImage: "server.rack")
                }
                .tag(0)

            SQLEditorView()
                .tabItem {
                    Label("Editor", systemImage: "terminal")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .environmentObject(databaseService)
        .accentColor(.white)
    }
}
