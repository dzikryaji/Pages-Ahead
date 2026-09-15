import SwiftUI

struct AppBackground: View {
    var color = AppTheme.background

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                color

                Image("Texture")
                    .resizable()
                    .scaledToFill()
                    .opacity(1)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
