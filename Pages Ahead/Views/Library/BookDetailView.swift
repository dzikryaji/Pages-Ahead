import SwiftUI

struct BookDetailView: View {
    private enum PendingAlert: Int, Identifiable {
        case saveStatus
        case deleteBook

        var id: Int { rawValue }
    }

    @State private var book: Book
    @State private var draftStatus: ReadingStatus
    @State private var editing = false
    @State private var pendingAlert: PendingAlert?
    let repository: LibraryViewModel
    @Bindable var sessionCoordinator: ReadingSessionCoordinator
    @Environment(\.dismiss) private var dismiss

    init(
        book: Book,
        repository: LibraryViewModel,
        sessionCoordinator: ReadingSessionCoordinator
    ) {
        _book = State(initialValue: book)
        _draftStatus = State(initialValue: book.status)
        self.repository = repository
        self.sessionCoordinator = sessionCoordinator
    }

    private var actionTitle: String {
        switch book.status {
        case .saved: "Start Reading"
        case .reading: "Continue Reading"
        case .finished: "Read Again"
        }
    }

    private var pageAfterDraftStatusChange: Int {
        sessionCoordinator.pageAfterStatusChange(for: book, to: draftStatus)
    }

    private var statusChangeConsequence: String {
        let destination = draftStatus.rawValue
        if draftStatus == .finished {
            return "This moves the book to Finished and sets progress to page \(book.pageCount) of \(book.pageCount)."
        }
        if book.status == .finished {
            if pageAfterDraftStatusChange == 0 {
                return "This changes the status to \(destination) and resets progress to page 0 because no partial latest session is available."
            }
            return "This changes the status to \(destination) and restores progress to page \(pageAfterDraftStatusChange) from the latest reading session."
        }
        return "This changes the status to \(destination) and keeps progress at page \(book.currentPage)."
    }

    private var deleteConsequence: String {
        let activeSessionWarning = sessionCoordinator.session?.bookID == book.id
            ? " The active reading session for this book will no longer be saveable."
            : ""
        return "This removes \(book.title) from your library. Reading sessions remain in Activity, but their book details will no longer be available.\(activeSessionWarning) This cannot be undone."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 14) {
                    BookCover(book: book, width: 116)
                    Text(book.title).font(AppTypography.displayTitle).tracking(0.4)
                        .multilineTextAlignment(.center)
                    Text(book.author).font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryText)

                    if book.hasPartialProgress {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: book.progress)
                            Text("Page \(book.currentPage)").font(
                                AppTypography.body
                            )
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .appCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Book Information")
                        .font(AppTypography.displaySection)

                    VStack(spacing: 12) {
                        DetailRow(label: "Edition") {
                            Text(book.edition)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }

                        Divider()

                        DetailRow(label: "ISBN") {
                            Text(book.isbn).foregroundStyle(.secondary)
                        }

                        Divider()

                        DetailRow(label: "Length") {
                            Text("\(book.pageCount) pages")
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        DetailRow(label: "Status") {
                            if editing {
                                Picker("Status", selection: $draftStatus) {
                                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                                        Text(status.rawValue).tag(status)
                                    }
                                }
                                .labelsHidden()
                                .accessibilityLabel("Status")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text(book.status.rawValue)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .appCard()
                }

                Button("Delete Book", role: .destructive) {
                    pendingAlert = .deleteBook
                }
                .frame(maxWidth: .infinity)
                .font(AppTypography.displayEyebrow)

                Button(actionTitle) {
                    repository.update(book)
                    _ = sessionCoordinator.start(
                        book: book,
                        origin: .bookDetail,
                        reread: book.status == .finished
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(editing)
                .accessibilityIdentifier("book-detail-reading-action")
            }
            .padding()
        }
        .appBackground()
        .navigationTitle("Book Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if editing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        draftStatus = book.status
                        editing = false
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    if editing {
                        if draftStatus == book.status {
                            editing = false
                        } else {
                            pendingAlert = .saveStatus
                        }
                    } else {
                        draftStatus = book.status
                        editing = true
                    }
                } label: {
                    Image(systemName: editing ? "checkmark" : "pencil")
                }
                .accessibilityLabel(editing ? "Save Book Changes" : "Edit Book")
            }
        }
        .alert(item: $pendingAlert) { alert in
            switch alert {
            case .saveStatus:
                Alert(
                    title: Text("Save status change?"),
                    message: Text(statusChangeConsequence),
                    primaryButton: .default(Text("Save Changes")) {
                        book.currentPage = pageAfterDraftStatusChange
                        book.status = draftStatus
                        repository.update(book)
                        editing = false
                    },
                    secondaryButton: .cancel()
                )
            case .deleteBook:
                Alert(
                    title: Text("Delete this book?"),
                    message: Text(deleteConsequence),
                    primaryButton: .destructive(Text("Delete Book")) {
                        repository.delete(book)
                        dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
