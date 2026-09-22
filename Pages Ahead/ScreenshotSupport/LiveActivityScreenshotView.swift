#if DEBUG
import SwiftUI

struct LiveActivityReferenceView: View {
    enum Mode { case lockScreen, expanded, compact, minimal }
    let mode: Mode
    let paused: Bool

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()
            switch mode {
            case .lockScreen: lockScreen
            case .expanded: expanded
            case .compact: compact
            case .minimal: minimal
            }
        }
    }

    private var lockScreen: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.pages.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(.white)
                .frame(width: 48, height: 64)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text("READING NOW").font(.caption2.bold()).foregroundStyle(AppTheme.accent)
                Text(SampleData.books[0].title).font(.headline).lineLimit(1)
                Text(SampleData.books[0].author).font(.caption).foregroundStyle(.secondary)
                if paused {
                    Label("19:48", systemImage: "pause.fill")
                        .font(.subheadline.monospacedDigit())
                } else {
                    ProgressView(value: 0.34).tint(AppTheme.accent)
                    Text("19:48 remaining").font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding()
        .background { AppBackground() }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(20)
    }

    private var expanded: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "book.fill").font(.system(size: 20))
                Spacer()
                VStack { Text(SampleData.books[0].title).font(.headline); Text(SampleData.books[0].author).font(.caption) }
                Spacer()
                Text("19:48").monospacedDigit()
            }
            ProgressView(value: 0.34).tint(.white)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(.black, in: Capsule())
        .padding(16)
    }

    private var compact: some View {
        HStack(spacing: 18) {
            Image(systemName: "book.fill").font(.system(size: 20))
            Text("19:48").monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.black, in: Capsule())
    }

    private var minimal: some View {
        Text("20m").font(.caption2.monospacedDigit()).foregroundStyle(.white)
            .frame(width: 42, height: 42).background(.black, in: Circle())
    }
}
#endif
