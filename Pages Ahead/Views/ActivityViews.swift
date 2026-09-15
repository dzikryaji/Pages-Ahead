import SwiftUI

struct ActivityView: View {
    @Bindable var viewModel: ActivityViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $viewModel.range) { Text("Week").tag("Week"); Text("Month").tag("Month") }.pickerStyle(.segmented)
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { metricCards }
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    } else {
                        HStack(spacing: 10) { metricCards }
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }
                }
                if viewModel.visibleRecords.isEmpty {
                    AppContentUnavailableView(
                        title: "Your reading story starts here",
                        systemName: "chart.bar.xaxis",
                        description: "Complete a reading session to see minutes, pages, history, and gentle patterns."
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("A gentle observation") {
                        Label(viewModel.insight, systemImage: "sparkles")
                            .font(AppTypography.body)
                    }
                    Section("History") {
                        ForEach(viewModel.visibleRecords) { record in
                            NavigationLink(value: record) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(viewModel.book(for: record)?.title ?? "Reading session").font(AppTypography.bodyBold)
                                    Text(record.date, format: .dateTime.weekday().month().day().hour().minute()).font(AppTypography.subheadline).foregroundStyle(AppTheme.secondaryText)
                                    AppSymbolLabel(
                                        title: "\(record.minutes) min · \(record.pages) pages",
                                        systemName: "book.pages",
                                        symbolSize: 15
                                    )
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .appBackground()
            .navigationTitle("Activity")
            .navigationDestination(for: ReadingRecord.self) { record in SessionDetailView(record: record, book: viewModel.book(for: record), viewModel: viewModel) }
            .onAppear(perform: viewModel.reload)
        }
    }

    @ViewBuilder private var metricCards: some View {
        MetricCard(value: "\(viewModel.totalMinutes)", label: "Minutes", symbol: "clock.fill")
        MetricCard(value: "\(viewModel.visibleRecords.count)", label: "Sessions", symbol: "book.fill")
        MetricCard(value: "\(viewModel.totalPages)", label: "Pages", symbol: "text.page.fill")
    }
}

struct SessionDetailView: View {
    @State private var record: ReadingRecord
    let book: Book?
    let viewModel: ActivityViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingDelete = false

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
    }

    var body: some View {
        List {
            if let book { Section("Book") { BookRow(book: book) } }
            Section("Session") {
                LabeledContent("Date", value: record.date.formatted(date: .abbreviated, time: .shortened))
                if editing { Stepper("\(record.minutes) minutes", value: $record.minutes, in: 1...240); Stepper("\(record.pages) pages", value: $record.pages, in: 0...200) }
                else { LabeledContent("Duration", value: "\(record.minutes) minutes"); LabeledContent("Pages", value: "\(record.pages)") }
                LabeledContent("Weather", value: record.weather); LabeledContent("Place", value: record.place)
            }
            Section("Reflection") {
                if editing { TextField("Feedback", text: $record.feedback); TextField("Note", text: $record.note, axis: .vertical) }
                else { LabeledContent("Feeling", value: record.feedback); if !record.note.isEmpty { Text(record.note) } }
            }
            Section { Button("Delete Session", role: .destructive) { confirmingDelete = true } }
        }
        .appBackground()
        .navigationTitle("Session Detail").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button(editing ? "Done" : "Edit") { if editing { viewModel.save(record) }; editing.toggle() } }
        .alert("Delete this session?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { viewModel.delete(record); dismiss() }; Button("Cancel", role: .cancel) { }
        } message: { Text("This cannot be undone.") }
    }
}

#Preview("Activity") {
    let container = AppContainer.preview
    ActivityView(viewModel: ActivityViewModel(repository: container.activity, library: container.library))
}

#Preview("Session Detail") {
    let container = AppContainer.preview
    let record = container.activity.records()[0]
    NavigationStack {
        SessionDetailView(record: record, book: container.library.books().first,
                          viewModel: ActivityViewModel(repository: container.activity, library: container.library))
    }
}
