import SwiftUI

struct ReadingSessionView: View {
    @Bindable var coordinator: ReadingSessionCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingClose = false
    @State private var confirmingStop = false

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.isShowingSummary {
                    SessionSummaryView(coordinator: coordinator)
                } else {
                    activeContent
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .interactiveDismissDisabled()
        .task(id: coordinator.session?.id) {
            while !Task.isCancelled, coordinator.session != nil {
                coordinator.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { coordinator.persistSnapshot() }
        }
    }

    private var activeContent: some View {
        VStack(spacing: 24) {
            HStack {
                Label("Reading Session", systemImage: "book.pages.fill").font(.headline)
                Spacer()
                Button("Close", systemImage: "xmark") { confirmingClose = true }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Close reading session")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer()
            if let book = coordinator.book {
                BookCover(book: book, width: 124)
                VStack(spacing: 6) {
                    Text(book.title).font(AppTypography.displayTitle)
                        .multilineTextAlignment(.center)
                    Text(book.author).font(AppTypography.body)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal)
            }
            Text(coordinator.timeText)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .accessibilityLabel("Elapsed time")
                .accessibilityValue(coordinator.timeText)
            Text(coordinator.isPaused ? "Paused" : "Reading")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if coordinator.isPaused {
                HStack(spacing: 12) {
                    Button {
                        Task { await coordinator.togglePause() }
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.bordered)
                    Button { confirmingStop = true } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button {
                    Task { await coordinator.togglePause() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .appBackground()
        .toolbar(.hidden, for: .navigationBar)
        .alert("End without saving?", isPresented: $confirmingClose) {
            Button("Keep Reading", role: .cancel) { }
            Button("End Without Saving", role: .destructive) {
                Task { await coordinator.endWithoutSaving() }
            }
        } message: {
            Text("Elapsed time and page progress will not be added to Activity.")
        }
        .alert("Stop reading?", isPresented: $confirmingStop) {
            Button("Cancel", role: .cancel) { }
            Button("Open Summary") {
                Task { await coordinator.stopForSummary() }
            }
        } message: {
            Text("Review elapsed time and enter your Last Page before saving.")
        }
    }
}
