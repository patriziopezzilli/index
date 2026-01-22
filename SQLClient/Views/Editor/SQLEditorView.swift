import SwiftUI

struct SQLEditorView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @State private var query = ""
    @State private var queryResult: QueryResult?
    @State private var isExecuting = false
    @State private var showingResults = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if !databaseService.isConnected {
                    NoConnectionView()
                } else {
                    VStack(spacing: 0) {
                        SQLEditorTextView(text: $query, isEditorFocused: $isEditorFocused)
                            .frame(height: showingResults ? 250 : nil)

                        if showingResults, let result = queryResult {
                            Divider()
                                .background(Color.white.opacity(0.1))

                            QueryResultView(result: result)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }

                if isExecuting {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Executing query...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("SQL Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if showingResults {
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    showingResults = false
                                    queryResult = nil
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Button(action: executeQuery) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Run")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.white)
                            )
                        }
                        .disabled(!databaseService.isConnected || query.isEmpty || isExecuting)
                    }
                }
            }
        }
    }

    private func executeQuery() {
        isEditorFocused = false
        isExecuting = true

        Task {
            let result = await databaseService.executeQuery(query)

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    queryResult = result
                    showingResults = true
                    isExecuting = false
                }
            }
        }
    }
}

struct SQLEditorTextView: View {
    @Binding var text: String
    var isEditorFocused: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding()
                .focused(isEditorFocused)

            if text.isEmpty {
                Text("Write your SQL query here...\n\nExample:\nSELECT * FROM users\nWHERE created_at > '2024-01-01';")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding()
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.white.opacity(0.05))
    }
}

struct NoConnectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text("No Active Connection")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Connect to a database to start executing queries")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}
