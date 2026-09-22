import SwiftUI
import UIKit

struct CachedCoverImage<Placeholder: View>: View {
    let url: URL
    let embeddedData: Data?
    let onImageLoaded: (Data) -> Void
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var image: UIImage?

    init(
        url: URL,
        embeddedData: Data?,
        onImageLoaded: @escaping (Data) -> Void = { _ in },
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.embeddedData = embeddedData
        self.onImageLoaded = onImageLoaded
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { placeholder() }
        }
        .task(id: url) {
            guard let data = try? await CoverImageCache.shared.data(for: url, embeddedData: embeddedData) else { return }
            image = UIImage(data: data)
            onImageLoaded(data)
        }
    }
}

struct BookCover: View {
    let book: Book?
    var width: CGFloat = 58
    private let onImageLoaded: (Data) -> Void

    init(
        book: Book?,
        width: CGFloat = 58,
        onImageLoaded: @escaping (Data) -> Void = { _ in }
    ) {
        self.book = book
        self.width = width
        self.onImageLoaded = onImageLoaded
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.12)
                .fill(AppTheme.coverGradient)

            if let book, let url = book.coverURL {
                CachedCoverImage(
                    url: url,
                    embeddedData: book.coverImageData,
                    onImageLoaded: onImageLoaded
                ) {
                    placeholder
                }
            } else if let data = book?.coverImageData,
                      let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(
            RoundedRectangle(cornerRadius: width * 0.12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: width * 0.12)
                .stroke(.white.opacity(0.7), lineWidth: 0.5)
        }
        .shadow(
            color: AppTheme.accent.opacity(0.18),
            radius: 6,
            y: 3
        )
        .accessibilityLabel(
            book.map { "Cover of \($0.title)" } ?? "Book cover"
        )
    }

    private var placeholder: some View {
        Text(book?.title ?? "Reading session")
            .font(
                .custom(
                    "BebasNeue-Regular",
                    size: max(10, width * 0.15)
                )
            )
            .tracking(0.3)
            .foregroundStyle(.white)
            .lineLimit(4)
            .padding(width * 0.12)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
    }
}

struct BookRow: View {
    let book: Book
    private let onCoverLoaded: (Data) -> Void

    init(
        book: Book,
        onCoverLoaded: @escaping (Data) -> Void = { _ in }
    ) {
        self.book = book
        self.onCoverLoaded = onCoverLoaded
    }

    var body: some View {
        HStack(spacing: 14) {
            BookCover(book: book, onImageLoaded: onCoverLoaded)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(AppTypography.bodyBold)
                Text(book.author)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                if book.status == .reading {
                    ProgressView(value: book.progress).tint(AppTheme.accent)
                    Text("Page \(book.currentPage) of \(book.pageCount)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
