//
//  ActivtyCard.swift
//  Pages Ahead
//
//  Created by Dzikry Aji Santoso on 22/09/26.
//

import SwiftUI

struct ActivityCard: View {
    let book: Book?
    let record: ReadingRecord

    var body: some View {
        HStack(spacing: 10) {
            BookCover(book: book, width: 75)

            VStack(alignment: .leading, spacing: 0) {
                Text(book?.title ?? "Reading session")
                    .font(AppTypography.bodyBold)
                    .padding(.bottom, 12)

                Text(
                    record.date,
                    format: .dateTime
                        .weekday()
                        .month()
                        .day()
                        .hour()
                        .minute()
                )
                .font(AppTypography.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

                Text("\(record.durationText) · \(record.pages) pages")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )

            Image(systemName: "chevron.right")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }
}

struct MetricCard: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22))

                .foregroundStyle(AppTheme.accent)
            Text(value).font(.title2.bold()).contentTransition(.numericText())
            Text(label).font(AppTypography.caption).foregroundStyle(
                AppTheme.secondaryText
            )
        }
        .backgroundStyle(Color.clear)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct DetailRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .frame(minHeight: 34)
    }
}
