import SwiftUI

struct SessionSummaryView: View {
    @Bindable var coordinator: ReadingSessionCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastPageText = ""
    @State private var ringRotation = 0.0
    @State private var checkScale = 0.5
    @State private var checkOpacity = 0.0
    @State private var didPrepare = false

    private var session: ActiveReadingSession? { coordinator.session }
    private var book: Book? { coordinator.book }
    private var lastPage: Int? { Int(lastPageText) }

    private var validationMessage: String? {
        guard let session, let book else { return "This book is no longer in your library." }
        guard let lastPage else { return "Enter Last Page." }
        if lastPage < session.startingPage {
            return "Last Page cannot be before page \(session.startingPage)."
        }
        if lastPage > book.pageCount {
            return "Last Page cannot be higher than page \(book.pageCount)."
        }
        return nil
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    ZStack {
                        UnevenCircle()
                            .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 92, height: 92)
                            .rotationEffect(.degrees(ringRotation))
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .scaleEffect(checkScale)
                            .opacity(checkOpacity)
                    }
                    .accessibilityHidden(true)
                    Text("Session complete").font(AppTypography.displayTitle)
                    Text("Record where you stopped.").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            Section("Session") {
                LabeledContent("Duration", value: coordinator.timeText)
                if let session {
                    LabeledContent("Started At", value: "Page \(session.startingPage)")
                }
                TextField("Last Page", text: $lastPageText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("session-summary-last-page")
                if let validationMessage {
                    Text(validationMessage).font(.footnote).foregroundStyle(.red)
                }
            }
            Section {
                Button("Save Session") {
                    guard let lastPage else { return }
                    Task { _ = await coordinator.save(lastPage: lastPage) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(validationMessage != nil)
                .accessibilityIdentifier("save-reading-session")
            }
            .listRowBackground(Color.clear)
        }
        .appBackground()
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .interactiveDismissDisabled()
        .onAppear(perform: prepare)
    }

    private func prepare() {
        guard !didPrepare else { return }
        didPrepare = true
        lastPageText = session.map { String($0.startingPage) } ?? ""
        guard !reduceMotion else {
            ringRotation = 0
            checkScale = 1
            checkOpacity = 1
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.68)) {
            checkScale = 1
            checkOpacity = 1
        }
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }
}

private struct UnevenCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        let points = 72
        for index in 0...points {
            let angle = Double(index) / Double(points) * .pi * 2
            let wobble = 1 + 0.035 * sin(angle * 3) + 0.02 * cos(angle * 5)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * wobble,
                y: center.y + CGFloat(sin(angle)) * radius * wobble
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
