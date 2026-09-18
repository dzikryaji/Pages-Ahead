import SwiftUI
import TipKit

struct ReadingWindowDetailView: View {
    let window: ReadingWindow
    let book: Book?
    let allBooks: [Book]
    let onPlan: () -> Void
    let reject: (String?) -> Void
    let chooseBook: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingReasons = false
    @State private var showingAlternatives = false
    private let rejectionTip = RejectionFeedbackTip()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(window.start, format: .dateTime.weekday(.wide).month().day())
                        .font(AppTypography.bodyBold)
                    Text(window.start.formatted(date: .omitted, time: .shortened) + "–" + window.end.formatted(date: .omitted, time: .shortened))
                        .font(AppTypography.displayLarge)
                        .minimumScaleFactor(0.7)
                    Label("\(window.temperature)° · \(window.condition)", systemImage: window.weatherSymbol)
                        .font(AppTypography.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            Section("Why it fits") {
                Text(window.fitReason)
                    .font(AppTypography.body)
            }
            if let book {
                Section("Suggested book") {
                    BookRow(book: book)
                    if allBooks.count > 1 {
                        Button("Choose Another Book", systemImage: "books.vertical") {
                            showingAlternatives = true
                        }
                    }
                }
            }
            Section {
                Button("Plan Reading") { onPlan(); dismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                Button("Not for Me", role: .destructive) { showingReasons = true }
                    .popoverTip(rejectionTip)
            }
        }
        .appBackground()
        .navigationTitle("Reading Window")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Why doesn’t this work?", isPresented: $showingReasons, titleVisibility: .visible) {
            Button("Weather") { rejectAndDismiss("Weather") }
            Button("Time") { rejectAndDismiss("Time") }
            Button("No Reason") { rejectAndDismiss(nil) }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAlternatives) {
            if let book {
                BookAlternativesView(books: allBooks, selected: book, choose: chooseBook)
            }
        }
        .task { await RejectionFeedbackTip.readingWindowDetailViewed.donate() }
    }

    private func rejectAndDismiss(_ reason: String?) {
        reject(reason)
        dismiss()
    }
}
