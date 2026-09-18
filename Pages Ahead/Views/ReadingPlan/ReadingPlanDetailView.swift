import SwiftUI
import UIKit

struct ReadingPlanDetailView: View {
    let plan: ReadingPlan
    let books: [Book]
    @Bindable var planManager: ReadingPlanManager
    @Bindable var sessionCoordinator: ReadingSessionCoordinator
    let initiallySelected: Book?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingBookPicker = false
    @State private var showingDelete = false
    @State private var pendingBook: Book?
    @State private var showingOutsideWindowAlert = false
    @State private var didStartReading = false

    var body: some View {
        List {
            Section("Reading window") {
                LabeledContent("Date", value: plan.start.formatted(date: .complete, time: .omitted))
                LabeledContent("Time", value: plan.start.formatted(date: .omitted, time: .shortened) + "–" + plan.end.formatted(date: .omitted, time: .shortened))
            }
            Section("Options") {
                Toggle("Notification", isOn: Binding(
                    get: { planManager.current?.reminderEnabled ?? false },
                    set: { enabled in Task {
                        let changed = await planManager.setNotification(enabled)
                        if !changed, case .openSettings = planManager.notice {
                            openURL(URL(string: UIApplication.openSettingsURLString)!)
                        }
                    } }
                ))
                Toggle("Calendar", isOn: Binding(
                    get: { planManager.current?.calendarEnabled ?? false },
                    set: { enabled in Task {
                        let changed = await planManager.setCalendar(enabled, bookTitle: initiallySelected?.title ?? "your book")
                        if !changed, case .openSettings = planManager.notice {
                            openURL(URL(string: UIApplication.openSettingsURLString)!)
                        }
                    } }
                ))
            }
            Section {
                Button("Start Reading", systemImage: "play.fill") { showingBookPicker = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .listRowBackground(Color.clear)
                Button("Delete Plan", role: .destructive) { showingDelete = true }
            }
        }
        .appBackground()
        .navigationTitle("Reading Plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingBookPicker) {
            ReadingSessionBookPicker(
                books: books.filter { $0.status != .finished },
                initiallySelected: initiallySelected?.status == .finished ? nil : initiallySelected
            ) { book in
                let inside = plan.start...plan.end ~= Date.now
                if inside { start(book, plan: plan, insideWindow: true) }
                else {
                    pendingBook = book
                    showingOutsideWindowAlert = true
                }
            }
        }
        .alert("Start outside your planned time?", isPresented: $showingOutsideWindowAlert) {
            Button("Keep Plan") {
                guard let pendingBook else { return }
                start(pendingBook, plan: plan, insideWindow: false)
            }
            Button("Remove Plan", role: .destructive) {
                Task {
                    guard let pendingBook, await planManager.deleteCurrent() else { return }
                    start(pendingBook, plan: nil, insideWindow: false)
                }
            }
            Button("Cancel", role: .cancel) { pendingBook = nil }
        } message: {
            Text("You can keep this plan for its original window or remove it before reading now.")
        }
        .alert("Delete this plan?", isPresented: $showingDelete) {
            Button("Delete Plan", role: .destructive) {
                Task { if await planManager.deleteCurrent() { dismiss() } }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: sessionCoordinator.isPresented) { wasPresented, isPresented in
            if didStartReading, wasPresented, !isPresented { dismiss() }
        }
    }

    private func start(_ book: Book, plan: ReadingPlan?, insideWindow: Bool) {
        didStartReading = sessionCoordinator.start(
            book: book,
            origin: .readingPlan,
            plan: plan,
            startedInsideWindow: insideWindow
        )
        pendingBook = nil
    }
}
