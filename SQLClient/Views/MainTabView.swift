import SwiftUI

struct MainTabView: View {
    @StateObject private var databaseService = DatabaseService()
    @State private var selectedTab = 0
    @State private var isSidebarVisible = true

    private func returnToConnections() {
        selectedTab = 0
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConnectionsListView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Connect", systemImage: "bolt.fill")
                }
                .tag(0)

            if databaseService.isConnected {
                WorkspaceTabContainer(isSidebarVisible: $isSidebarVisible, onReturnToConnections: returnToConnections)
                    .tabItem {
                        Label("Workspace", systemImage: "sparkles")
                    }
                    .tag(1)
            }

            QueryHistoryView(onRerun: { query in
                if let ws = databaseService.currentWorkspace {
                    let newTab = WorkspaceSubTab(name: "SQL Worksheet", type: .editor)
                    ws.subTabs.append(newTab)
                    ws.selectedSubTabId = newTab.id
                    ws.queryToRun = query
                }
                selectedTab = 1
            })
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .environmentObject(databaseService)
        .tint(.blue)
    }
}

struct WorkspaceTabContainer: View {
    @EnvironmentObject var dbService: DatabaseService
    @Binding var isSidebarVisible: Bool
    let onReturnToConnections: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if dbService.activeWorkspaces.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(dbService.activeWorkspaces.enumerated()), id: \.element.id) { index, workspace in
                            WorkspaceTabButton(
                                workspace: workspace,
                                isSelected: dbService.selectedWorkspaceIndex == index,
                                onSelect: { dbService.selectedWorkspaceIndex = index },
                                onClose: { dbService.disconnect(workspace: workspace) }
                            )
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .frame(height: 40)
            }
            
            if let currentWorkspace = dbService.currentWorkspace {
                DatabaseWorkspaceView(
                    workspace: currentWorkspace, 
                    isSidebarVisible: $isSidebarVisible,
                    onReturnToConnections: onReturnToConnections
                )
            }
        }
    }
}

struct WorkspaceTabButton: View {
    @ObservedObject var workspace: WorkspaceTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: workspace.connection.type.icon)
                        .foregroundColor(workspace.connection.type.color)
                        .font(.caption)
                    
                    Text(workspace.connection.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
                .padding(.leading, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(isSelected ? Color(.systemBackground) : Color.clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
    }
}
