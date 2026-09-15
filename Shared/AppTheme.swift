//
//  AppTheme.swift
//  Pages Ahead
//
//  Created by Dzikry Aji Santoso on 11/09/26.
//

import SwiftUI

enum AppTheme {
    static let background = Color("BackgroundColor")
    static let ink = Color(red: 33 / 255, green: 33 / 255, blue: 33 / 255)
    static let secondaryText = Color(red: 95 / 255, green: 95 / 255, blue: 95 / 255)
    static let tertiaryText = Color(red: 112 / 255, green: 112 / 255, blue: 112 / 255)
    static let border = Color(red: 133 / 255, green: 133 / 255, blue: 133 / 255)
    static let surface = Color.white
    static let subtleSurface = Color.white.opacity(0.72)
    static let selectedSurface = ink.opacity(0.08)

    static let coverGradient = LinearGradient(
        colors: [ink, Color(red: 80 / 255, green: 80 / 255, blue: 80 / 255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum AppTypography {
    static let displaySuperLarge = Font.custom(
        "BebasNeue-Regular",
        size: 64,
        relativeTo: .largeTitle
    )
    static let displayLarge = Font.custom(
        "BebasNeue-Regular",
        size: 48,
        relativeTo: .largeTitle
    )
    static let displayTitle = Font.custom(
        "BebasNeue-Regular",
        size: 34,
        relativeTo: .title
    )
    static let displaySection = Font.custom(
        "BebasNeue-Regular",
        size: 26,
        relativeTo: .title2
    )
    static let displayEyebrow = Font.custom(
        "BebasNeue-Regular",
        size: 18,
        relativeTo: .headline
    )

    static let body = Font.custom("Nunito-Regular", size: 18, relativeTo: .body)
    static let bodySemibold = Font.custom(
        "Nunito-SemiBold",
        size: 18,
        relativeTo: .body
    )
    static let bodyBold = Font.custom("Nunito-Bold", size: 18, relativeTo: .body)
    static let description = Font.custom(
        "Nunito-Regular",
        size: 20,
        relativeTo: .title3
    )
    static let subheadline = Font.custom(
        "Nunito-Regular",
        size: 16,
        relativeTo: .subheadline
    )
    static let subheadlineSemibold = Font.custom(
        "Nunito-SemiBold",
        size: 16,
        relativeTo: .subheadline
    )
    static let caption = Font.custom(
        "Nunito-Regular",
        size: 12,
        relativeTo: .caption
    )
}

private struct AppCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: AppTheme.ink.opacity(0.07), radius: 10, y: 4)
    }
}

extension View {
    func appCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(AppCardModifier(cornerRadius: cornerRadius))
    }
}
