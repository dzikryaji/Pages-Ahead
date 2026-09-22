//
//  OnboardingIntroductionFlowView.swift
//  Pages Ahead
//
//  Created by Dzikry Aji Santoso on 15/09/26.
//


import SwiftUI
import UIKit

struct OnboardingIntroductionFlowView: View {
    @Bindable var viewModel: AppFlowViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pages = [
        IntroPage(
            page: .welcome,
            symbol: "onboarding.book.weather",
            title: "Welcome to Pages Ahead",
            message:
                "Pages Ahead finds your best time to read, based on the weather and your preferred time."
        ),
        IntroPage(
            page: .outcome,
            symbol: "cloud.sun.fill",
            title: "Your data stays with you",
            message:
                "Your data and preferences are stored only on your device. We only use your location to check the weather."
        ),
        IntroPage(
            page: .howItWorks,
            symbol: "cloud.rain.fill",
            title: "A few preferences go a long way",
            message:
                "Tell us a bit about when and how you like to read, and Pages Ahead narrows it down to the best windows."
        ),
    ]

    private var currentPage: OnboardingPage {
        viewModel.draft.currentPage.group == .intro
            ? viewModel.draft.currentPage : .welcome
    }

    private var selection: Binding<OnboardingPage> {
        Binding(
            get: { currentPage },
            set: { page in
                guard page.group == .intro else { return }
                viewModel.go(to: page)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if currentPage != .welcome {
                    Button("Back", action: viewModel.goBack)
                }
                Spacer()
                if currentPage == .welcome {
                    Button("Skip Intro", action: viewModel.skipIntroduction)
                }
            }
            .padding(.horizontal, 32)
            .font(AppTypography.description)
            .frame(minHeight: 44)

            TabView(selection: selection) {
                ForEach(Self.pages) { page in
                    IntroPageContent(page: page)
                        .tag(page.page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(Self.pages) { page in
                        Circle()
                            .fill(
                                page.page == currentPage
                                ? AppTheme.accent : AppTheme.accent.opacity(0.5)
                            )
                            .frame(width: 8, height: 8)
                            .scaleEffect(page.page == currentPage ? 1.35 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Introduction progress")
                .accessibilityValue("Page \(currentPage.rawValue) of 3")

                Button(
                    currentPage == .howItWorks ? "Continue to Setup" : "Next",
                    action: viewModel.continueIntroduction
                )
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 32)
        .padding(.top, 50)
        .appBackground()
        .animation(
            reduceMotion ? nil : .spring(duration: 0.35),
            value: currentPage
        )
        .onChange(of: currentPage) { _, page in
            guard
                let title = Self.pages.first(where: { $0.page == page })?.title
            else { return }
            UIAccessibility.post(
                notification: .screenChanged,
                argument: String(localized: title)
            )
        }
        .ignoresSafeArea()
    }
}

private struct IntroPage: Identifiable {
    let page: OnboardingPage
    let symbol: String
    let title: LocalizedStringResource
    let message: LocalizedStringKey

    var id: OnboardingPage { page }
}

private struct IntroPageContent: View {
    let page: IntroPage

    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            Text(page.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(AppTypography.displaySuperLarge)
            AppSymbol(systemName: page.symbol, size: 250)
                .foregroundStyle(AppTheme.accent)
                .accessibilityHidden(true)
            Text(page.message)
                .font(AppTypography.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
