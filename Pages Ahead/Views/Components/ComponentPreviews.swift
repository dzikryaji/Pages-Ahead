import SwiftUI

#Preview("App Background") {
    AppBackground()
}

#Preview("Cached Cover Image") {
    CachedCoverImage(url: URL(string: "https://example.invalid/cover.jpg")!, embeddedData: nil) {
        AppTheme.coverGradient.overlay {
            AppSymbol(systemName: "book.fill", size: 28)
                .foregroundStyle(.white)
        }
    }
    .frame(width: 120, height: 174)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding()
}

#Preview("Book Cover") {
    BookCover(book: SampleData.books[0], width: 120).padding().appBackground()
}

#Preview("Book Row") {
    BookRow(book: SampleData.books[0]).padding().appBackground()
}

#Preview("Metric Card") {
    MetricCard(value: "42", label: "Minutes", symbol: "clock.fill").padding().appBackground()
}
