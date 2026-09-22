import SwiftUI

struct ActivityView: View {
    @Bindable var viewModel: ActivityViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("Activity")
                        .font(AppTypography.displayLarge)
                    Spacer()
                    //                        Button {
                    //                            // action
                    //                        } label: {
                    //                            Image(systemName: "plus")
                    //                                .font(.system(size: 20, weight: .semibold))
                    //                                .foregroundStyle(.primary)
                    //                                .padding(12)
                    //                        }
                    //                        .glassEffect(.regular.interactive(), in: .circle)
                }
                Picker("Range", selection: $viewModel.range) {
                    ForEach(ActivityRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 12)

                TabView(selection: $viewModel.range) {
                    ForEach(ActivityRange.allCases) { range in
                        activityPage(for: range)
                            .tag(range)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.top, 58)
            .padding(.bottom)
            .padding(.horizontal)
            .appBackground()
            .navigationDestination(for: ReadingRecord.self) { record in
                SessionDetailView(
                    record: record,
                    book: viewModel.book(for: record),
                    viewModel: viewModel
                )
            }
            .onAppear(perform: viewModel.reload)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func activityPage(for range: ActivityRange) -> some View {
        let records = viewModel.records(for: range)

        if records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.periodTitle(for: range))
                    .font(AppTypography.displaySection)
                    .padding(.top, 20)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { metricCards(for: range) }
                        .padding(.vertical, 12)
                } else {
                    HStack(spacing: 10) { metricCards(for: range) }
                        .padding(.vertical, 12)
                }
                
                AppContentUnavailableView(
                    title:
                        "No sessions in \(viewModel.periodTitle(for: range).lowercased())",
                    systemName: "chart.bar.xaxis",
                    description:
                        "Complete a reading session to see time, pages, history, and gentle patterns."
                )
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.periodTitle(for: range))
                        .font(AppTypography.displaySection)

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 10) { metricCards(for: range) }
                    } else {
                        HStack(spacing: 10) { metricCards(for: range) }
                    }
                    Label(
                        viewModel.insight(for: range),
                        systemImage: "sparkles"
                    )
                    .font(AppTypography.body)

                    ForEach(records) { record in
                        NavigationLink(value: record) {
                            ActivityCard(
                                book: viewModel.book(for: record),
                                record: record
                            )
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder private func metricCards(for range: ActivityRange) -> some View
    {
        MetricCard(
            value: "\(viewModel.totalMinutes(for: range))",
            label: "Minutes",
            symbol: "clock.fill"
        )
        MetricCard(
            value: "\(viewModel.records(for: range).count)",
            label: "Sessions",
            symbol: "book.fill"
        )
        MetricCard(
            value: "\(viewModel.totalPages(for: range))",
            label: "Pages",
            symbol: "text.page.fill"
        )
    }
}
