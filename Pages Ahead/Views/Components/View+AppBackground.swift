import SwiftUI

private struct AppScreenBackgroundModifier: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .scrollContentBackground(.hidden)
                .background { AppBackground() }
        } else {
            content
        }
    }
}

extension View {
    func appBackground(enabled: Bool = true) -> some View {
        modifier(AppScreenBackgroundModifier(enabled: enabled))
    }
}
