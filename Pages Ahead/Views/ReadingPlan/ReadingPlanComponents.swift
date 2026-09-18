import SwiftUI

struct FeaturedReadingWindowCard: View {
    let window: ReadingWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(window.start, format: .dateTime.weekday(.wide).month().day())
                        .font(AppTypography.bodySemibold)
                    Text(window.start.formatted(date: .omitted, time: .shortened) + "–" + window.end.formatted(date: .omitted, time: .shortened))
                        .font(AppTypography.displayTitle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: window.weatherSymbol).font(.title2)
                    Text("\(window.temperature)°").font(.title3.bold())
                    Text(window.condition).font(AppTypography.caption)
                }
            }
            Text(window.fitReason)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(3)
            HStack {
                Text("View details").font(AppTypography.subheadlineSemibold)
                Spacer()
                Image(systemName: "chevron.right")
            }
        }
        .padding()
        .appCard()
        .accessibilityElement(children: .combine)
    }
}

struct ReadingWindowRow: View {
    let window: ReadingWindow

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: window.weatherSymbol)
                .font(.title2)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(window.start, format: .dateTime.weekday(.wide).month().day())
                    .font(AppTypography.bodyBold)
                Text(window.start.formatted(date: .omitted, time: .shortened) + "–" + window.end.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text("\(window.temperature)°").font(.title3.bold())
            Image(systemName: "chevron.right").foregroundStyle(AppTheme.tertiaryText)
        }
        .padding()
        .appCard()
        .accessibilityElement(children: .combine)
    }
}

struct BookAlternativesView: View {
    let books: [Book]
    let choose: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var choice: Book.ID

    init(books: [Book], selected: Book, choose: @escaping (Book) -> Void) {
        self.books = books
        self.choose = choose
        _choice = State(initialValue: selected.id)
    }

    var body: some View {
        NavigationStack {
            List(books) { book in
                Button { choice = book.id } label: {
                    HStack {
                        BookRow(book: book)
                        Spacer()
                        if choice == book.id { Image(systemName: "checkmark.circle.fill") }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Choose", systemImage: "checkmark") {
                        if let book = books.first(where: { $0.id == choice }) { choose(book) }
                        dismiss()
                    }
                }
            }
        }
    }
}
