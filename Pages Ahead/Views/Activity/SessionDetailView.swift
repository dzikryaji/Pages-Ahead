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
        editMinutes >= 0 &&
        editLastPage >= record.startingPage &&
        editLastPage <= (book?.pageCount ?? Int.max)
    }

    var body: some View {
        List {
            if let book {
                Section("Book") { BookRow(book: book) }
            }
            Section("Session") {
                LabeledContent(
                    "Date",
                    value: record.date.formatted(date: .abbreviated, time: .shortened)
                )
                if editing {
                    LabeledContent("Duration") {
                        HStack {
                            TextField("Minutes", value: $editMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("min").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Last Page") {
                        TextField("Last Page", value: $editLastPage, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if !editIsValid {
                        Text("Last Page must be between \(record.startingPage) and \(book?.pageCount ?? record.lastPage).")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } else {
                    LabeledContent("Duration", value: record.durationText)
                    LabeledContent("Pages Read", value: "\(record.pages)")
                    LabeledContent("Last Page", value: "\(record.lastPage)")
                }
                LabeledContent("Weather", value: record.weather)
            }
            Section {
                Button("Delete Session", role: .destructive) { confirmingDelete = true }
            }
        }
        .appBackground()
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(editing ? "Done" : "Edit") {
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
            }
            .disabled(editing && !editIsValid)
        }
        .alert("Delete this session?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) {
                viewModel.delete(record)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Book progress may rewind when this is the latest session.")
        }
        .alert("Couldn’t Save Changes", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Try again.")
        }
    }
}
