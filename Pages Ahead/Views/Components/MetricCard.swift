import SwiftUI

struct MetricCard: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if HandDrawnSymbol.assetName(for: symbol) != nil {
                    AppSymbol(systemName: symbol, size: 22)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 22))
                }
            }
            .foregroundStyle(AppTheme.ink)
            Text(value).font(.title2.bold()).contentTransition(.numericText())
            Text(label).font(AppTypography.caption).foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
