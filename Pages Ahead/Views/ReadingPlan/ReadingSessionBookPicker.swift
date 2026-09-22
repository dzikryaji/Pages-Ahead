import SwiftUI

struct ReadingSessionBookPicker: View {
    let books: [Book]
    let onStart: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: Book.ID?

    init(books: [Book], initiallySelected: Book?, onStart: @escaping (Book) -> Void) {
        self.books = books
        self.onStart = onStart
        _selectedID = State(initialValue: initiallySelected?.id)
    }

    var body: some View {
        NavigationStack {
            List(books) { book in
                Button {
                    selectedID = book.id
                } label: {
                    HStack {
                        BookRow(book: book)
                        Spacer()
                        Image(systemName: selectedID == book.id ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedID == book.id ? AppTheme.accent : AppTheme.tertiaryText)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedID == book.id ? .isSelected : [])
            }
            .navigationTitle("Choose a Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", systemImage: "play.fill") {
                        guard let book = books.first(where: { $0.id == selectedID }) else { return }
                        dismiss()
                        onStart(book)
                    }
                    .disabled(selectedID == nil)
                }
            }
        }
    }
}
