import SwiftUI

struct ActivityView: View {
    @Bindable var viewModel: ActivityViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Range", selection: $viewModel.range) {
                        Text("Week").tag("Week")
                        Text("Month").tag("Month")
                        Text("All Time").tag("All Time")
                    }
                    .pickerStyle(.segmented)

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { metricCards }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else {
                        HStack(spacing: 10) { metricCards }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if viewModel.visibleRecords.isEmpty {
                    AppContentUnavailableView(
                        title: "Your reading story starts here",
                        systemName: "chart.bar.xaxis",
                        description: "Complete a reading session to see time, pages, history, and gentle patterns."
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
                                    Text(viewModel.book(for: record)?.title ?? "Reading session")
                                        .font(AppTypography.bodyBold)
                                    Text(record.date, format: .dateTime.weekday().month().day().hour().minute())
                                        .font(AppTypography.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    AppSymbolLabel(
                                        title: "\(record.durationText) · \(record.pages) pages",
                                        systemName: "book.pages",
                                        symbolSize: 15
                                    )
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .appBackground()
            .navigationTitle("Activity")
            .navigationDestination(for: ReadingRecord.self) { record in
                SessionDetailView(
                    record: record,
                    book: viewModel.book(for: record),
                    viewModel: viewModel
                )
            }
            .onAppear(perform: viewModel.reload)
        }
    }

    @ViewBuilder private var metricCards: some View {
        MetricCard(value: "\(viewModel.totalMinutes)", label: "Minutes", symbol: "clock.fill")
        MetricCard(value: "\(viewModel.visibleRecords.count)", label: "Sessions", symbol: "book.fill")
        MetricCard(value: "\(viewModel.totalPages)", label: "Pages", symbol: "text.page.fill")
    }
}
