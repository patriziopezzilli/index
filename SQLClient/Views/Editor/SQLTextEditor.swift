import SwiftUI
import UIKit

struct SQLTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Write your SQL query here..."
    var onFormat: (() -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.tintColor = .systemBlue
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.keyboardAppearance = .default

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barStyle = .default

        let formatButton = UIBarButtonItem(
            title: "Format",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.formatTapped)
        )

        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )

        toolbar.items = [formatButton, spacer, doneButton]
        textView.inputAccessoryView = toolbar

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            applySyntaxHighlighting(to: uiView)
            uiView.selectedRange = selectedRange
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applySyntaxHighlighting(to textView: UITextView) {
        let attributedString = NSMutableAttributedString(string: textView.text)

        attributedString.addAttributes([
            .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.label
        ], range: NSRange(location: 0, length: attributedString.length))

        highlightPattern(
            in: attributedString,
            pattern: "\\b(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|DROP|ALTER|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AS|AND|OR|NOT|IN|BETWEEN|LIKE|IS|NULL|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|DISTINCT|PRIMARY|KEY|FOREIGN|REFERENCES|AUTO_INCREMENT|AUTOINCREMENT|INTEGER|TEXT|VARCHAR|BOOLEAN|REAL|DECIMAL)\\b",
            color: UIColor.systemBlue,
            options: [.caseInsensitive]
        )

        highlightPattern(
            in: attributedString,
            pattern: "\\b(COUNT|SUM|AVG|MIN|MAX|ROUND|UPPER|LOWER|LENGTH|TRIM|DATE|NOW|COALESCE)\\s*\\(",
            color: UIColor.systemPurple,
            options: [.caseInsensitive]
        )

        highlightPattern(
            in: attributedString,
            pattern: "'[^']*'|\"[^\"]*\"",
            color: UIColor.systemGreen
        )

        highlightPattern(
            in: attributedString,
            pattern: "\\b\\d+(\\.\\d+)?\\b",
            color: UIColor.systemOrange
        )

        highlightPattern(
            in: attributedString,
            pattern: "--[^\n]*",
            color: UIColor.systemGray
        )

        textView.attributedText = attributedString
    }

    private func highlightPattern(
        in attributedString: NSMutableAttributedString,
        pattern: String,
        color: UIColor,
        options: NSRegularExpression.Options = []
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return
        }

        let range = NSRange(location: 0, length: attributedString.length)
        let matches = regex.matches(in: attributedString.string, options: [], range: range)

        for match in matches {
            attributedString.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SQLTextEditor

        init(_ parent: SQLTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.applySyntaxHighlighting(to: textView)
        }

        @objc func formatTapped() {
            parent.onFormat?()
        }

        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
