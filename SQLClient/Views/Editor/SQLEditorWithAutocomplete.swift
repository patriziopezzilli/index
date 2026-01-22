import SwiftUI

struct SQLEditorWithAutocomplete: View {
    @Binding var text: String
    @EnvironmentObject var dbService: DatabaseService
    var onFormat: (() -> Void)?

    @State private var suggestions: [SQLAutocomplete.Suggestion] = []
    @State private var showSuggestions = false
    @State private var cursorPosition: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            SQLTextEditor(
                text: $text,
                onFormat: onFormat
            )
            .onChange(of: text) { _, newValue in
                updateSuggestions(for: newValue)
            }

            // Autocomplete suggestions overlay
            if showSuggestions && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    Spacer()

                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)

                            Text("Suggestions")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { showSuggestions = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))

                        Divider()
                            .background(Color.white.opacity(0.2))

                        // Suggestions list
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions.prefix(10), id: \.text) { suggestion in
                                    SuggestionButton(suggestion: suggestion) {
                                        insertSuggestion(suggestion)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 80)
                    }
                    .background(Color.black.opacity(0.95))
                    .cornerRadius(12, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding(.bottom, 44) // Account for keyboard toolbar
            }
        }
    }

    private func updateSuggestions(for query: String) {
        // Get the word at cursor position
        let currentWord = getCurrentWord(from: query)

        guard !currentWord.isEmpty else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSuggestions = false
            }
            return
        }

        // Get suggestions from autocomplete helper
        let schema = dbService.currentSchema
        let newSuggestions = SQLAutocomplete.getSuggestions(
            for: query,
            currentWord: currentWord,
            schema: schema
        )

        if newSuggestions.isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSuggestions = false
            }
        } else {
            suggestions = newSuggestions
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showSuggestions = true
            }
        }
    }

    private func getCurrentWord(from query: String) -> String {
        // Find the word at the end of the query (simplified)
        let components = query.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components.last ?? ""
    }

    private func insertSuggestion(_ suggestion: SQLAutocomplete.Suggestion) {
        let currentWord = getCurrentWord(from: text)

        // Replace the current word with the suggestion
        if let range = text.range(of: currentWord, options: .backwards) {
            text.replaceSubrange(range, with: suggestion.text)

            // Add space after if it's a keyword
            if suggestion.type == .keyword {
                text += " "
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showSuggestions = false
        }
    }
}

struct SuggestionButton: View {
    let suggestion: SQLAutocomplete.Suggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.icon)
                    .font(.caption)
                    .foregroundColor(suggestion.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.text)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    if let detail = suggestion.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

extension SQLAutocomplete.Suggestion {
    var icon: String {
        switch type {
        case .keyword:
            return "keyboard"
        case .table:
            return "tablecells"
        case .column:
            return "rectangle.3.group"
        case .function:
            return "function"
        }
    }

    var color: Color {
        switch type {
        case .keyword:
            return .blue
        case .table:
            return .green
        case .column:
            return .orange
        case .function:
            return .purple
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
