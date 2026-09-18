import SwiftUI
import TipKit

struct RejectionFeedbackTip: Tip {
    static let readingWindowDetailViewed = Tips.Event(
        id: "reading-window-detail-viewed"
    )

    var title: Text { Text("Improve future suggestions") }
    var message: Text? {
        Text(
            "Tap Not for Me and choose why this window missed. Pages Ahead uses that reason on this device to tune future reading windows."
        )
    }
    var image: Image? {
        guard let image = HandDrawnSymbol.uiImage(for: "slider.horizontal.3") else {
            return Image(systemName: "slider.horizontal.3")
        }
        return Image(uiImage: image).renderingMode(.template)
    }

    var rules: [Rule] {
        #Rule(Self.readingWindowDetailViewed) { event in
            event.donations.count >= 2
        }
    }

    var options: [Option] {
        MaxDisplayCount(3)
    }
}

struct PermissionRecoveryTip: Tip {
    var title: Text { Text("Restore plan integrations") }
    var message: Text? {
        Text("Notification or Calendar access was previously denied. Turn an option on to open Settings and allow access.")
    }
    var image: Image? { Image(systemName: "gearshape.badge") }
    var options: [Option] { MaxDisplayCount(1) }
}
