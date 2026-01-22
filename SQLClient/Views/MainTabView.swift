import SwiftUI

struct MainTabView: View {
    @StateObject private var databaseService = DatabaseService()
    @State private var selectedTab = 0
    @State private var queryToRun: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            ConnectionsListView()
                .tabItem {
                    Label("Connections", systemImage: "server.rack")
                }
                .tag(0)

            SQLEditorView(queryToRun: $queryToRun)
                .tabItem {
                    Label("Editor", systemImage: "terminal")
                }
                .tag(1)

            QueryHistoryView(onRerun: { query in
                queryToRun = query
                selectedTab = 1  // Switch to editor tab
            })
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
