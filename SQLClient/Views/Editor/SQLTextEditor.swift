import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SQLTextEditor: View {
    @Binding var text: String
    var placeholder: String = "Write your SQL query here..."
    var onFormat: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .font(.system(size: 16, design: .monospaced))
            }

            TextEditor(text: $text)
                .font(.system(size: 16, design: .monospaced))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .toolbar {
            if let onFormat = onFormat {
                ToolbarItem(placement: .automatic) {
                    Button(action: onFormat) {
                        Label("Format", systemImage: "text.alignleft")
                    }
                }
            }
        }
    }
}
