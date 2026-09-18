import Testing
import UIKit
@testable import Pages_Ahead

@Suite("Design system")
struct DesignSystemTests {
    @Test("Bundled brand fonts are registered")
    func bundledBrandFontsAreRegistered() {
        #expect(UIFont(name: "BebasNeue-Regular", size: 24) != nil)
        #expect(UIFont(name: "Nunito-Regular", size: 17) != nil)
        #expect(UIFont(name: "Nunito-SemiBold", size: 17) != nil)
        #expect(UIFont(name: "Nunito-Bold", size: 17) != nil)
    }

    @Test("Retained hand-drawn symbol mappings resolve and unknown names fall back")
    func handDrawnSymbolMappings() {
        let expected: [String: String] = [
            "onboarding.book.weather": "onboarding.book.weather",
            "onboarding.location": "onboarding.location",
            "book.pages.fill": "handdrawn.book.pages",
            "book.fill": "handdrawn.book",
            "books.vertical.fill": "handdrawn.books.vertical",
            "chart.bar.xaxis": "handdrawn.chart.bar.xaxis",
            "cloud.bolt.fill": "handdrawn.cloud.bolt",
            "cloud.bolt.rain.fill": "handdrawn.cloud.bolt.rain",
            "cloud.fog.fill": "handdrawn.cloud.fog",
            "cloud.fill": "handdrawn.cloud",
            "cloud.rain.fill": "handdrawn.cloud.rain",
            "cloud.snow.fill": "handdrawn.cloud.snow",
            "cloud.sun.fill": "handdrawn.cloud.sun",
            "moon.fill": "handdrawn.moon",
            "moon.stars.fill": "handdrawn.moon.stars",
            "sun.max.fill": "handdrawn.sun.max",
            "text.book.closed.fill": "handdrawn.text.book.closed",
            "text.page.fill": "handdrawn.text.page",
        ]

        for (systemName, assetName) in expected {
            #expect(HandDrawnSymbol.assetName(for: systemName) == assetName)
        }
        #expect(HandDrawnSymbol.assetName(for: "sparkles") == nil)
    }

    @Test("Hand-drawn symbol mappings and catalog entries stay consistent")
    func handDrawnSymbolCatalogConsistency() throws {
        let mappedSystemNames = [
            "onboarding.book.weather", "onboarding.location",
            "book.pages", "book.pages.fill", "book", "book.fill",
            "books.vertical", "books.vertical.fill", "chart.bar.xaxis",
            "cloud.bolt", "cloud.bolt.fill", "cloud.bolt.rain", "cloud.bolt.rain.fill",
            "cloud.fog", "cloud.fog.fill", "cloud", "cloud.fill",
            "cloud.rain", "cloud.rain.fill", "cloud.snow", "cloud.snow.fill",
            "cloud.sun", "cloud.sun.fill", "moon", "moon.fill",
            "moon.stars", "moon.stars.fill", "sun.max", "sun.max.fill",
            "text.book.closed", "text.book.closed.fill", "text.page", "text.page.fill",
        ]
        let mappedAssets = Set(mappedSystemNames.compactMap(HandDrawnSymbol.assetName(for:)))

        for assetName in mappedAssets.sorted() {
            #expect(UIImage(named: assetName) != nil, "Missing catalog image: \(assetName)")
        }

        for systemName in mappedSystemNames {
            #expect(
                HandDrawnSymbol.uiImage(for: systemName) != nil,
                "Mapped symbol failed to render: \(systemName)"
            )
        }

        let projectDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogDirectory = projectDirectory
            .appendingPathComponent("Pages Ahead", isDirectory: true)
            .appendingPathComponent("Assets.xcassets", isDirectory: true)
        let catalogAssets = try FileManager.default
            .contentsOfDirectory(at: catalogDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "imageset" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0.hasPrefix("handdrawn.") || $0.hasPrefix("onboarding.") }

        #expect(Set(catalogAssets) == mappedAssets)
    }

    @Test("Screenshot scenario identifiers are typed and unique")
    func screenshotScenarioIdentifiers() {
        let rawValues = ScreenshotScenario.allCases.map(\.rawValue)

        #expect(rawValues.count == 51)
        #expect(Set(rawValues).count == rawValues.count)
        #expect(ScreenshotScenario(rawValue: "onboarding_welcome") == .onboardingWelcome)
        #expect(ScreenshotScenario(rawValue: "main_tabs_reading_plan") == .mainTabsReadingPlan)
        #expect(ScreenshotScenario(rawValue: "reading_window_detail") == .readingWindowDetail)
        #expect(ScreenshotScenario(rawValue: "main_tabs_forecast") == nil)
        #expect(ScreenshotScenario(rawValue: "unknown") == nil)
    }
}
