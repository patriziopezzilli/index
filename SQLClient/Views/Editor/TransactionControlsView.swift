import SwiftUI

struct TransactionControlsView: View {
    @ObservedObject var workspace: WorkspaceTab
    @EnvironmentObject var dbService: DatabaseService

    @State private var showingCommitConfirmation = false
    @State private var showingRollbackConfirmation = false
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            // Transaction status indicator
            TransactionStatusBadge(state: workspace.transactionState, queryCount: workspace.transactionQueryCount)

            Spacer()

            // Transaction controls
            if workspace.isInTransaction {
                // Commit button
                Button(action: { showingCommitConfirmation = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Commit")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
                }
                .disabled(isProcessing)

                // Rollback button
                Button(action: { showingRollbackConfirmation = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text("Rollback")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.red)
                    )
                }
                .disabled(isProcessing)
            } else {
                // Begin Transaction button
                Button(action: beginTransaction) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                        Text("Begin Transaction")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
                }
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            workspace.isInTransaction
                ? Color.orange.opacity(0.1)
                : Color(.secondarySystemBackground)
        )
        .alert("Commit Transaction", isPresented: $showingCommitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Commit", role: .destructive) {
                commitTransaction()
            }
        } message: {
            Text("Are you sure you want to commit all changes (\(workspace.transactionQueryCount) queries) to the database? This action cannot be undone.")
        }
        .alert("Rollback Transaction", isPresented: $showingRollbackConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Rollback", role: .destructive) {
                rollbackTransaction()
            }
        } message: {
            Text("Are you sure you want to rollback all changes? All \(workspace.transactionQueryCount) queries in this transaction will be discarded.")
        }
    }

    private func beginTransaction() {
        isProcessing = true

        Task {
            let result = await dbService.executeQuery("BEGIN TRANSACTION;", in: workspace)

            await MainActor.run {
                isProcessing = false
                if result.isSuccess {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        workspace.transactionState = .active
                        workspace.transactionQueryCount = 0
                    }
                }
            }
        }
    }

    private func commitTransaction() {
        isProcessing = true

        Task {
            let result = await dbService.executeQuery("COMMIT;", in: workspace)

            await MainActor.run {
                isProcessing = false
                if result.isSuccess {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        workspace.transactionState = .none
                        workspace.transactionQueryCount = 0
                    }
                }
            }
        }
    }

    private func rollbackTransaction() {
        isProcessing = true

        Task {
            let result = await dbService.executeQuery("ROLLBACK;", in: workspace)

            await MainActor.run {
                isProcessing = false
                if result.isSuccess {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        workspace.transactionState = .none
                        workspace.transactionQueryCount = 0
                    }
                }
            }
        }
    }
}

struct TransactionStatusBadge: View {
    let state: TransactionState
    let queryCount: Int

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 3)
                )
                .shadow(color: statusColor.opacity(0.5), radius: state == .active ? 4 : 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                if state == .active {
                    Text("\(queryCount) queries pending")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor.opacity(0.1))
        )
    }

    private var statusColor: Color {
        switch state {
        case .none:
            return .gray
        case .active:
            return .orange
        case .pending:
            return .blue
        }
    }

    private var statusText: String {
        switch state {
        case .none:
            return "Auto-commit"
        case .active:
            return "Transaction Active"
        case .pending:
            return "Processing..."
        }
    }
}

// MARK: - Compact Transaction Indicator (for header)

struct TransactionIndicator: View {
    @ObservedObject var workspace: WorkspaceTab
    @State private var isPulsing = false

    var body: some View {
        if workspace.isInTransaction {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear { isPulsing = true }

                Text("TXN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.orange)

                if workspace.transactionQueryCount > 0 {
                    Text("(\(workspace.transactionQueryCount))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )
        }
    }
}

// MARK: - Quick Transaction Menu

struct TransactionQuickMenu: View {
    @ObservedObject var workspace: WorkspaceTab
    @EnvironmentObject var dbService: DatabaseService
    @State private var isProcessing = false

    var body: some View {
        Menu {
            if workspace.isInTransaction {
                Section {
                    Text("Transaction Active")
                        .font(.caption)
                    Text("\(workspace.transactionQueryCount) queries pending")
                        .font(.caption)
                }

                Divider()

                Button(action: commit) {
                    Label("Commit Changes", systemImage: "checkmark.circle")
                }

                Button(role: .destructive, action: rollback) {
                    Label("Rollback All", systemImage: "arrow.uturn.backward.circle")
                }
            } else {
                Button(action: begin) {
                    Label("Begin Transaction", systemImage: "play.circle")
                }

                Divider()

                Text("Auto-commit is ON")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: workspace.isInTransaction ? "lock.rotation" : "lock.open.rotation")
                    .font(.system(size: 14))
                    .foregroundColor(workspace.isInTransaction ? .orange : .secondary)

                if workspace.isInTransaction {
                    Text("TXN")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(workspace.isInTransaction ? Color.orange.opacity(0.1) : Color(.secondarySystemBackground))
            )
        }
        .disabled(isProcessing)
    }

    private func begin() {
        isProcessing = true
        Task {
            let result = await dbService.executeQuery("BEGIN TRANSACTION;", in: workspace)
            await MainActor.run {
                isProcessing = false
                if result.isSuccess {
                    workspace.transactionState = .active
                    workspace.transactionQueryCount = 0
                }
            }
        }
    }

    private func commit() {
        isProcessing = true
        Task {
            let result = await dbService.executeQuery("COMMIT;", in: workspace)
            await MainActor.run {
                isProcessing = false
                if result.isSuccess {
                    workspace.transactionState = .none
                    workspace.transactionQueryCount = 0
                }
            }
        }
    }

    private func rollback() {
        isProcessing = true
        Task {
            let result = await dbService.executeQuery("ROLLBACK;", in: workspace)
            await MainActor.run {
                isProcessing = false
                if result.isSuccess {
                    workspace.transactionState = .none
                    workspace.transactionQueryCount = 0
                }
            }
        }
    }
}

#Preview("Transaction Controls - Inactive") {
    let workspace = WorkspaceTab(
        connection: DatabaseConnection(
            name: "Test",
            type: .sqlite,
            host: "",
            port: nil,
            database: "test.db",
            username: "",
            password: ""
        ),
        driver: MockDatabaseDriver()
    )
    return TransactionControlsView(workspace: workspace)
        .environmentObject(DatabaseService())
}

#Preview("Transaction Controls - Active") {
    let workspace = WorkspaceTab(
        connection: DatabaseConnection(
            name: "Test",
            type: .sqlite,
            host: "",
            port: nil,
            database: "test.db",
            username: "",
            password: ""
        ),
        driver: MockDatabaseDriver()
    )
    workspace.transactionState = .active
    workspace.transactionQueryCount = 5
    return TransactionControlsView(workspace: workspace)
        .environmentObject(DatabaseService())
}

// Mock driver for previews
private class MockDatabaseDriver: DatabaseDriver {
    var connection: DatabaseConnection = DatabaseConnection(
        name: "Mock",
        type: .sqlite,
        host: "",
        port: nil,
        database: "mock.db",
        username: "",
        password: ""
    )
    var isConnected: Bool = true

    func connect() async throws {}
    func disconnect() throws {}
    func execute(_ query: String) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: 0, executionTime: 0)
    }
    func loadSchema() async throws -> DatabaseSchema {
        DatabaseSchema(name: "mock")
    }
    func fetchTableData(tableName: String, page: Int, pageSize: Int) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: 0, executionTime: 0)
    }
    func updateCell(tableName: String, columnName: String, newValue: String, primaryKeyColumn: String, primaryKeyValue: String) async throws {}
}
