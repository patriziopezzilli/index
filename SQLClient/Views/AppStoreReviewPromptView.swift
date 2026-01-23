import SwiftUI

struct AppStoreReviewPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowing = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundColor(.yellow)

            Text("Ti piace INDEX?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Se ti piace la nostra app SQL client, considera di lasciarci una recensione su App Store. Ci aiuta molto!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Più tardi") {
                    AppStoreReviewService.shared.dismissReviewPrompt()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Valuta ora") {
                    AppStoreReviewService.shared.requestReview()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            isShowing = true
        }
    }
}

struct AppStoreReviewPromptView_Previews: PreviewProvider {
    static var previews: some View {
        AppStoreReviewPromptView()
    }
}