import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
import FirebaseAnalytics

class AppStoreReviewService {
    static let shared = AppStoreReviewService()

    private let hasReviewedKey = "hasReviewedApp"
    private let workspaceOpensKey = "workspaceOpensCount"

    private init() {}

    var hasReviewed: Bool {
        get { UserDefaults.standard.bool(forKey: hasReviewedKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasReviewedKey) }
    }

    var workspaceOpensCount: Int {
        get { UserDefaults.standard.integer(forKey: workspaceOpensKey) }
        set { UserDefaults.standard.set(newValue, forKey: workspaceOpensKey) }
    }

    func incrementWorkspaceOpens() {
        workspaceOpensCount += 1
    }

    func shouldShowReviewPrompt() -> Bool {
        // Mostra il prompt dopo la prima apertura di workspace se non ha già valutato
        return !hasReviewed && workspaceOpensCount >= 1
    }

    func requestReview() {
        // Firebase Analytics: track review request
        Analytics.logEvent("review_requested", parameters: [
            "workspace_opens": workspaceOpensCount
        ])

        // Su macOS non c'è StoreKit come su iOS, quindi apriamo l'App Store manualmente
        // IMPORTANTE: Sostituisci "YOUR_APP_ID" con l'ID effettivo della tua app su App Store
        // Puoi trovare l'App ID nella pagina del tuo prodotto su App Store Connect
        let appStoreURL = "macappstore://apps.apple.com/app/id6758221968?action=write-review"

        if let url = URL(string: appStoreURL) {
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
            hasReviewed = true
        } else {
            // Fallback: apri la pagina App Store generale
            let fallbackURL = "https://apps.apple.com/app/id6758221968"
            if let url = URL(string: fallbackURL) {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
                hasReviewed = true
            }
        }
    }

    func dismissReviewPrompt() {
        hasReviewed = true // Non mostrare più il prompt
    }
}