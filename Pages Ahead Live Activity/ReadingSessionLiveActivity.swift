import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PagesAheadLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        ReadingSessionLiveActivity()
    }
}

struct ReadingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionActivityAttributes.self) { context in
            ReadingSessionActivityView(
                title: context.attributes.bookTitle,
                author: context.attributes.bookAuthor,
                startedAt: context.state.startedAt,
                endsAt: context.state.endsAt,
                remainingSeconds: context.state.remainingSeconds,
                isPaused: context.state.isPaused
            )
            .background {
                GeometryReader { proxy in
                    ZStack {
                        AppTheme.background
                        Image("Texture")
                            .resizable()
                            .scaledToFill()
                            .opacity(0.1)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .accessibilityHidden(true)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .activityBackgroundTint(AppTheme.background)
            .activitySystemActionForegroundColor(activityInk)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(activityInk)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.bookTitle).font(.headline).lineLimit(1)
                        Text(context.attributes.bookAuthor).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionTimeView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(activityInk)
            } compactTrailing: {
                SessionTimeView(state: context.state, compact: true)
            } minimal: {
                SessionTimeView(state: context.state, compact: true)
            }
            .keylineTint(activityInk)
        }
    }
}

private struct ReadingSessionActivityView: View {
    let title: String
    let author: String
    let startedAt: Date
    let endsAt: Date
    let remainingSeconds: Int
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.pages.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(.white)
                .frame(width: 48, height: 64)
                .background(activityInk, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text("READING NOW").font(.caption2.bold())
                Text(title).font(.headline).lineLimit(1)
                Text(author).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                ZStack(alignment: .bottomLeading) {
                    Label(durationText(remainingSeconds), systemImage: "pause.fill")
                        .font(.subheadline.monospacedDigit())
                        .opacity(isPaused ? 1 : 0)
                        .accessibilityHidden(!isPaused)
                    VStack(alignment: .leading, spacing: 5) {
                        ProgressView(timerInterval: startedAt...endsAt, countsDown: false)
                            .tint(activityInk)
                        Text(timerInterval: Date.now...endsAt, countsDown: true)
                            .font(.subheadline.monospacedDigit())
                    }
                    .opacity(isPaused ? 0 : 1)
                    .accessibilityHidden(isPaused)
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

private let activityInk = Color(
    red: 33 / 255,
    green: 33 / 255,
    blue: 33 / 255
)

private struct SessionTimeView: View {
    let state: ReadingSessionActivityAttributes.ContentState
    var compact = false

    var body: some View {
        if state.isPaused {
            if compact {
                Image(systemName: "pause.fill")
                    .font(.system(size: 14))
            } else {
                Label(durationText(state.remainingSeconds), systemImage: "pause.fill")
                    .font(.caption.monospacedDigit())
            }
        } else {
            Text(timerInterval: Date.now...state.endsAt, countsDown: true)
                .font((compact ? Font.caption2 : Font.body).monospacedDigit())
                .frame(maxWidth: compact ? 42 : nil)
        }
    }
}

private func durationText(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

private let previewAttributes = ReadingSessionActivityAttributes(
    bookID: UUID(),
    bookTitle: "The Left Hand of Darkness",
    bookAuthor: "Ursula K. Le Guin",
    durationSeconds: 1_800
)

private let runningPreviewState = ReadingSessionActivityAttributes.ContentState(
    startedAt: .now.addingTimeInterval(-600),
    endsAt: .now.addingTimeInterval(1_200),
    remainingSeconds: 1_200,
    isPaused: false
)

private let pausedPreviewState = ReadingSessionActivityAttributes.ContentState(
    startedAt: .now.addingTimeInterval(-600),
    endsAt: .now.addingTimeInterval(1_200),
    remainingSeconds: 1_200,
    isPaused: true
)

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    ReadingSessionLiveActivity()
} contentStates: {
    runningPreviewState
    pausedPreviewState
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    ReadingSessionLiveActivity()
} contentStates: {
    runningPreviewState
    pausedPreviewState
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    ReadingSessionLiveActivity()
} contentStates: {
    runningPreviewState
    pausedPreviewState
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    ReadingSessionLiveActivity()
} contentStates: {
    runningPreviewState
    pausedPreviewState
}
