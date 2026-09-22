import SwiftUI
import UIKit

extension View {
    /// Disables the pan/swipe gesture on a `.page`-style `TabView`.
    ///
    /// SwiftUI doesn't expose any API for this — a `.page` `TabView` is
    /// backed by a `UIPageViewController`, which owns its own internal
    /// `UIScrollView` for paging. This drops to UIKit, walks up from an
    /// invisible helper view to find that scroll view, and toggles
    /// `isScrollEnabled` on it. Apply it directly to the `TabView`:
    ///
    ///     TabView(selection: $selection) { ... }
    ///         .tabViewStyle(.page(indexDisplayMode: .never))
    ///         .swipeDisabled()
    ///
    /// Programmatic navigation (setting `selection`, e.g. from Next/Back
    /// buttons) still animates normally — only the finger-driven swipe is
    /// blocked.
    func swipeDisabled(_ disabled: Bool = true) -> some View {
        background(SwipeGestureLock(disabled: disabled))
    }
}

private struct SwipeGestureLock: UIViewRepresentable {
    let disabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The TabView's UIScrollView may not exist yet the first time this
        // runs (right after makeUIView), so defer a tick.
        DispatchQueue.main.async {
            applyLock(from: uiView)
        }
    }

    private func applyLock(from view: UIView) {
        guard let scrollView = findScrollView(from: view) else { return }
        scrollView.isScrollEnabled = !disabled
    }

    /// Walks up the ancestor chain and, at each level, searches that
    /// ancestor's whole subtree for a `UIScrollView`. Starting from the
    /// closest ancestor and expanding outward finds the TabView's paging
    /// scroll view reliably without needing to know the exact hierarchy
    /// depth (which can shift between iOS versions).
    private func findScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while let candidate = current {
            if let match = recursiveFind(in: candidate) {
                return match
            }
            current = candidate.superview
        }
        return nil
    }

    private func recursiveFind(in view: UIView) -> UIScrollView? {
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let match = recursiveFind(in: subview) {
                return match
            }
        }
        return nil
    }
}

struct OnboardingChoiceGroup<Value: Hashable>: View {
    let title: LocalizedStringKey
    let values: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    init(
        title: LocalizedStringKey,
        values: [Value],
        selection: Binding<Value>,
        label: @escaping (Value) -> String = { String(describing: $0) }
    ) {
        self.title = title
        self.values = values
        _selection = selection
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(AppTypography.bodyBold)
            ForEach(values, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    HStack {
                        Text(label(value))
                        Spacer()
                        Image(
                            systemName: selection == value
                                ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(
                            selection == value
                                ? AppTheme.accent : AppTheme.tertiaryText
                        )
                    }
                    .frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(
                        selection == value
                            ? AppTheme.selectedSurface : AppTheme.surface,
                        in: RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                selection == value
                                    ? AppTheme.accent
                                    : AppTheme.accent.opacity(0.4),
                                lineWidth: selection == value ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
    }
}

struct OnboardingWindowChoice: View {
    let window: ReadingWindow
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    AppSymbol(systemName: window.weatherSymbol, size: 30).frame(
                        width: 38
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(window.start.readingDay).font(.headline)
                        Text(window.readingTimeRange).font(
                            AppTypography.subheadline
                        )
                        Text(
                            "\(window.condition), \(window.temperature)° · \(window.place)"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Image(
                        systemName: selected
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.system(size: 24))
                    .foregroundStyle(
                        selected ? AppTheme.accent : AppTheme.tertiaryText
                    )
                }
                Text(window.fitReason).font(AppTypography.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                if window.isCached {
                    Label(
                        "Cached forecast",
                        systemImage: "clock.arrow.circlepath"
                    ).font(AppTypography.caption)
                }
            }
            .padding(16)
            .background(
                selected ? AppTheme.selectedSurface : AppTheme.surface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        selected ? AppTheme.accent : AppTheme.accent.opacity(0.4),
                        lineWidth: selected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
