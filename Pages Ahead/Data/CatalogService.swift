import Foundation

enum CatalogError: LocalizedError {
    case invalidQuery
    case invalidResponse
    case rateLimited
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidQuery: "Enter a title or ISBN."
        case .invalidResponse: "Book catalog returned an unexpected response."
        case .rateLimited: "Book catalog is busy. Try again in a moment."
        case .unavailable: "Book catalog is temporarily unavailable. Check your connection and try again."
        }
    }
}

struct OpenLibraryCatalogService: BookCatalogSearching {
    private struct Response: Decodable { let docs: [Document] }
    private struct Document: Decodable {
        let key: String
        let title: String
        let authorName: [String]?
        let firstPublishYear: Int?
        let isbn: [String]?
        let numberOfPagesMedian: Int?
        let coverI: Int?

        enum CodingKeys: String, CodingKey {
            case key, title, isbn
            case authorName = "author_name"
            case firstPublishYear = "first_publish_year"
            case numberOfPagesMedian = "number_of_pages_median"
            case coverI = "cover_i"
        }
    }

    func search(query: String) async throws -> [Book] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CatalogError.invalidQuery }
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "fields", value: "key,title,author_name,first_publish_year,isbn,number_of_pages_median,cover_i"),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components.url else { throw CatalogError.invalidQuery }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("PagesAhead/1.0 (book search)", forHTTPHeaderField: "User-Agent")
        let data = try await load(request)
        return try decode(data)
    }

    func decode(_ data: Data) throws -> [Book] {
        let documents = try JSONDecoder().decode(Response.self, from: data).docs
        return documents.map { document in
            let isbn = document.isbn?.first ?? ""
            let coverURL = document.coverI.flatMap { URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg?default=false") }
            return Book(
                id: UUID(), title: document.title,
                author: document.authorName?.first ?? "Unknown author",
                edition: document.firstPublishYear.map { "First published \($0)" } ?? "Edition not listed",
                isbn: isbn, pageCount: document.numberOfPagesMedian ?? 0,
                status: .saved, currentPage: 0,
                coverURL: coverURL, catalogSource: "Open Library · \(document.key)"
            )
        }
    }

    private func load(_ request: URLRequest) async throws -> Data {
        for attempt in 0..<3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw CatalogError.invalidResponse }
                if 200..<300 ~= http.statusCode { return data }
                let retryable = http.statusCode == 429 || 500..<600 ~= http.statusCode
                guard retryable else { throw CatalogError.invalidResponse }
                if attempt == 2 { throw http.statusCode == 429 ? CatalogError.rateLimited : CatalogError.unavailable }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as CatalogError {
                throw error
            } catch {
                if attempt == 2 { throw CatalogError.unavailable }
            }
            try await Task.sleep(for: .milliseconds(400 * (attempt + 1)))
        }
        throw CatalogError.unavailable
    }
}

struct PreviewCatalogService: BookCatalogSearching {
    func search(query: String) async throws -> [Book] {
        SampleData.books.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.isbn.contains(query)
        }
    }
}
