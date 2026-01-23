import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var databaseService: DatabaseService
    @State private var showingResetAlert = false
    @State private var showingClearHistoryAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 0) {
                            SettingsRow(
                                icon: "info.circle.fill",
                                title: "About",
                                subtitle: "INDEX v1.0",
                                color: .blue
                            )

                            Divider()
                                .padding(.leading, 60)

                            SettingsRow(
                                icon: "app.badge.fill",
                                title: "App Version",
                                subtitle: "1.0.0 (Build 1)",
                                color: .purple
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "hand.tap.fill")
                                    .foregroundColor(.blue)
                                Text("Appearance")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Display Density")
                                            .font(.system(size: 16, weight: .medium))
                                        Text(appState.displayDensity == .compact ? "Desktop friendly" : "Touch friendly")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Picker("Display Density", selection: $appState.displayDensity) {
                                        ForEach(DisplayDensity.allCases, id: \.self) { density in
                                            Text(density.rawValue).tag(density)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 160)
                                    .onChange(of: appState.displayDensity) { _, newValue in
                                        UserDefaults.standard.set(newValue.rawValue, forKey: "displayDensity")
                                    }
                                }
                                .padding()
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.green)
                                Text("Performance")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 0) {
                                NavigationLink(destination: VoiceToSQLView()) {
                                    SettingsRow(
                                        icon: "mic.fill",
                                        title: "Voice-to-SQL",
                                        subtitle: "Speak your queries",
                                        color: .blue
                                    )
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }

                        VStack(spacing: 0) {
                            Button(action: {
                                showingClearHistoryAlert = true
                            }) {
                                SettingsRow(
                                    icon: "trash.circle.fill",
                                    title: "Clear Query History",
                                    subtitle: "\(databaseService.queryHistory.count) queries",
                                    color: .orange,
                                    showChevron: false
                                )
                            }

                            Divider()
                                .padding(.leading, 60)

                            Button(action: {
                                showingResetAlert = true
                            }) {
                                SettingsRow(
                                    icon: "arrow.counterclockwise.circle.fill",
                                    title: "Reset App",
                                    subtitle: "Clear all data and connections",
                                    color: .red,
                                    showChevron: false
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                        )

                        VStack(spacing: 12) {
                            Image(systemName: "cylinder.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.4))

                            Text("INDEX - SQL Client")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)

                            Text("A beautiful, minimal SQL client\nfor iOS and iPadOS")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear Query History", isPresented: $showingClearHistoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    databaseService.queryHistory.removeAll()
                    UserDefaults.standard.removeObject(forKey: "queryHistory")
                }
            } message: {
                Text("This will permanently delete all query history. This action cannot be undone.")
            }
            .alert("Reset App", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetApp()
                }
            } message: {
                Text("This will delete all connections, query history, and reset the app to its initial state. This action cannot be undone.")
            }
        }
    }

    private func resetApp() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "savedConnections")
        UserDefaults.standard.removeObject(forKey: "queryHistory")

        appState.hasCompletedOnboarding = false
        appState.connections.removeAll()
        databaseService.queryHistory.removeAll()
        databaseService.disconnectAll()
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding()
    }
}
