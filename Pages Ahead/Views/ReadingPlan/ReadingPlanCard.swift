import SwiftUI

struct ReadingPlanCard: View {
    let plan: ReadingPlan

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(AppTheme.selectedSurface, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.start, format: .dateTime.weekday(.wide).month().day())
                    .font(AppTypography.bodyBold)
                Text(plan.start.formatted(date: .omitted, time: .shortened) + "–" + plan.end.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding()
        .appCard()
        .accessibilityElement(children: .combine)
    }
}
