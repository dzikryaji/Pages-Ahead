import SwiftUI
import UIKit

actor CoverImageCache: BookCoverImageLoading {
    static let shared = CoverImageCache()
    private let session: URLSession
    private let cache: URLCache
    private var downloads: [URL: Task<Data, Error>] = [:]

    private init() {
        let configuration = URLSessionConfiguration.default
        cache = URLCache(memoryCapacity: 20 * 1_024 * 1_024,
                         diskCapacity: 100 * 1_024 * 1_024,
                         diskPath: "PagesAheadBookCovers")
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
    }

    func data(for url: URL, embeddedData: Data?) async throws -> Data {
        let request = URLRequest(url: url)
        if let embeddedData {
            let response = URLResponse(url: url, mimeType: "image/jpeg", expectedContentLength: embeddedData.count, textEncodingName: nil)
            cache.storeCachedResponse(CachedURLResponse(response: response, data: embeddedData), for: request)
            return embeddedData
        }

        if let cached = cache.cachedResponse(for: request) { return cached.data }
        if let download = downloads[url] { return try await download.value }

        let session = session
        let download = Task<Data, Error> {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            return data
        }
        downloads[url] = download
        defer { downloads[url] = nil }

        let data = try await download.value
        let response = URLResponse(
            url: url,
            mimeType: "image/jpeg",
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        cache.storeCachedResponse(
            CachedURLResponse(response: response, data: data),
            for: request
        )
        return data
    }
}

private struct CachedCoverImage<Placeholder: View>: View {
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
    let book: Book
    var width: CGFloat = 58
    private let onImageLoaded: (Data) -> Void

    init(
        book: Book,
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
            if let url = book.coverURL {
                CachedCoverImage(
                    url: url,
                    embeddedData: book.coverImageData,
                    onImageLoaded: onImageLoaded
                ) { placeholder }
            } else if let data = book.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { placeholder }
        }
            .frame(width: width, height: width * 1.45).clipShape(RoundedRectangle(cornerRadius: width * 0.12))
            .overlay {
                RoundedRectangle(cornerRadius: width * 0.12)
                    .stroke(.white.opacity(0.7), lineWidth: 0.5)
            }
            .shadow(color: AppTheme.ink.opacity(0.18), radius: 6, y: 3)
            .accessibilityLabel("Cover of \(book.title)")
    }

    private var placeholder: some View {
        Text(book.title)
            .font(.custom("BebasNeue-Regular", size: max(10, width * 0.15)))
            .tracking(0.3)
            .foregroundStyle(.white).lineLimit(4).padding(width * 0.12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                    ProgressView(value: book.progress).tint(AppTheme.ink)
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

struct MetricCard: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if HandDrawnSymbol.assetName(for: symbol) != nil {
                    AppSymbol(systemName: symbol, size: 22)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 22))
                }
            }
            .foregroundStyle(AppTheme.ink)
            Text(value).font(.title2.bold()).contentTransition(.numericText())
            Text(label).font(AppTypography.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(
                AppTheme.ink.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

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

extension Date {
    var readingDay: String { formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
    var readingTime: String { formatted(date: .omitted, time: .shortened) }
}

#Preview("App Background") {
    AppBackground()
}

#Preview("Cached Cover Image") {
    CachedCoverImage(url: URL(string: "https://example.invalid/cover.jpg")!, embeddedData: nil) {
        AppTheme.coverGradient.overlay {
            AppSymbol(systemName: "book.closed.fill", size: 28)
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
