import SwiftUI

struct SessionDetailView: View {
    @State private var record: ReadingRecord
    let book: Book?
    @Bindable var viewModel: ActivityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Bool
    @State private var confirmingDelete: Bool
    @State private var editMinutes: Int
    @State private var editLastPage: Int
    @State private var showingError = false

    init(
        record: ReadingRecord,
        book: Book?,
        viewModel: ActivityViewModel,
        editing: Bool = false,
        confirmingDelete: Bool = false
    ) {
        _record = State(initialValue: record)
        self.book = book
        self.viewModel = viewModel
        _editing = State(initialValue: editing)
        _confirmingDelete = State(initialValue: confirmingDelete)
        _editMinutes = State(initialValue: max(0, record.durationSeconds / 60))
        _editLastPage = State(initialValue: record.lastPage)
    }

    private var editIsValid: Bool {
        editMinutes >= 0 && editLastPage >= record.startingPage
            && editLastPage <= (book?.pageCount ?? Int.max)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let book {
                BookRow(book: book)
            }

            Text("Session")
                .font(AppTypography.displaySection)

            VStack(spacing: 12) {
                DetailRow(label: "Date") {
                    Text(
                        record.date.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .foregroundStyle(.secondary)
                }

                Divider()

                if editing {
                    DetailRow(label: "Duration") {
                        HStack(spacing: 4) {
                            TextField(
                                "Minutes",
                                value: $editMinutes,
                                format: .number
                            )
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            Text("min")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    DetailRow(label: "Last Page") {
                        TextField("Page", value: $editLastPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .overlay {
                                if !editIsValid {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(.red, lineWidth: 1)
                                }
                            }
                    }

                    if !editIsValid {
                        Text(
                            "Enter a page between \(record.startingPage) and \(book?.pageCount ?? record.lastPage)."
                        )
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    DetailRow(label: "Duration") {
                        Text("\(record.minutes) min").foregroundStyle(
                            .secondary
                        )
                    }

                    Divider()

                    DetailRow(label: "Last Page") {
                        Text("\(record.lastPage)").foregroundStyle(.secondary)
                    }
                }

                Divider()

                DetailRow(label: "Pages Read") {
                    Text("\(record.pages)").foregroundStyle(.secondary)
                }

                Divider()

                DetailRow(label: "Weather") {
                    Text(record.weather).foregroundStyle(.secondary)
                }
            }
            .padding()
            .appCard()

            Spacer()

            Button("Delete Session", role: .destructive) {
                confirmingDelete = true
            }
            .frame(maxWidth: .infinity)
            .font(AppTypography.displaySection)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                if editing {
                    guard editIsValid else { return }
                    let updated = record.with(
                        lastPage: editLastPage,
                        durationSeconds: editMinutes * 60
                    )
                    guard viewModel.save(updated) else {
                        showingError = true
                        return
                    }
                    record = updated
                } else {
                    editMinutes = max(0, record.durationSeconds / 60)
                    editLastPage = record.lastPage
                }
                editing.toggle()
            } label: {
                Image(
                    systemName: editing ? "checkmark" : "pencil"
                )
            }
            .disabled(editing && !editIsValid)
        }
        .alert("Delete this session?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                viewModel.delete(record)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Book progress may rewind when this is the latest session.")
        }
        .alert("Couldn’t Save Changes", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Try again.")
        }
    }
}
