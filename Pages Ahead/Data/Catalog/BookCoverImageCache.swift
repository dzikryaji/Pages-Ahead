import Foundation

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
