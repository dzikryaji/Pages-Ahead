import SwiftUI
import UIKit

enum HandDrawnSymbol {
    private static let croppedImageCache = NSCache<NSString, UIImage>()
    private static let renderedImageCache = NSCache<NSString, UIImage>()

    static func assetName(for systemName: String) -> String? {
        switch systemName {
        case "onboarding.book.weather":
            "onboarding.book.weather"
        case "onboarding.location":
            "onboarding.location"
        case "book.closed", "book.closed.fill":
            "handdrawn.book.closed"
        case "book.pages", "book.pages.fill":
            "handdrawn.book.pages"
        case "book", "book.fill":
            "handdrawn.book"
        case "books.vertical", "books.vertical.fill":
            "handdrawn.books.vertical"
        case "chart.bar", "chart.bar.fill":
            "handdrawn.chart.bar"
        case "chart.bar.xaxis":
            "handdrawn.chart.bar.xaxis"
        case "chart.line.uptrend.xyaxis":
            "handdrawn.chart.line.uptrend.xyaxis"
        case "cloud.bolt", "cloud.bolt.fill":
            "handdrawn.cloud.bolt"
        case "cloud.bolt.rain", "cloud.bolt.rain.fill":
            "handdrawn.cloud.bolt.rain"
        case "cloud.fog", "cloud.fog.fill":
            "handdrawn.cloud.fog"
        case "cloud", "cloud.fill":
            "handdrawn.cloud"
        case "cloud.rain", "cloud.rain.fill":
            "handdrawn.cloud.rain"
        case "cloud.snow", "cloud.snow.fill":
            "handdrawn.cloud.snow"
        case "cloud.sun", "cloud.sun.fill":
            "handdrawn.cloud.sun"
        case "moon", "moon.fill":
            "handdrawn.moon"
        case "moon.stars", "moon.stars.fill":
            "handdrawn.moon.stars"
        case "sun.max", "sun.max.fill":
            "handdrawn.sun.max"
        case "text.book.closed", "text.book.closed.fill":
            "handdrawn.text.book.closed"
        case "text.page", "text.page.fill":
            "handdrawn.text.page"
        case "thermometer.medium":
            "handdrawn.thermometer.medium"
        default:
            nil
        }
    }

    static func uiImage(for systemName: String, pointSize: CGFloat = 24) -> UIImage? {
        guard let assetName = assetName(for: systemName) else { return nil }
        let renderedKey = "\(assetName)-\(pointSize)" as NSString
        if let cached = renderedImageCache.object(forKey: renderedKey) {
            return cached
        }

        guard let source = croppedImage(for: assetName) else { return nil }

        let targetSize = CGSize(width: pointSize, height: pointSize)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            let padding = pointSize * 0.06
            let availableSize = pointSize - padding * 2
            let scale = min(
                availableSize / source.size.width,
                availableSize / source.size.height
            )
            let drawSize = CGSize(
                width: source.size.width * scale,
                height: source.size.height * scale
            )
            source.draw(in: CGRect(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
        renderedImageCache.setObject(rendered, forKey: renderedKey)
        return rendered
    }

    private static func croppedImage(for assetName: String) -> UIImage? {
        let cacheKey = assetName as NSString
        if let cached = croppedImageCache.object(forKey: cacheKey) {
            return cached
        }

        guard let source = UIImage(named: assetName, in: .main, compatibleWith: nil),
              let sourceImage = source.cgImage
        else { return nil }

        let width = sourceImage.width
        let height = sourceImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minimumX = width
        var minimumY = height
        var maximumX = 0
        var maximumY = 0
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] >= 24 {
                minimumX = min(minimumX, x)
                minimumY = min(minimumY, y)
                maximumX = max(maximumX, x)
                maximumY = max(maximumY, y)
            }
        }

        guard minimumX <= maximumX, minimumY <= maximumY,
              let normalizedImage = context.makeImage(),
              let cropped = normalizedImage.cropping(to: CGRect(
                x: minimumX,
                y: minimumY,
                width: maximumX - minimumX + 1,
                height: maximumY - minimumY + 1
              ))
        else { return nil }

        let result = UIImage(cgImage: cropped)
        croppedImageCache.setObject(result, forKey: cacheKey)
        return result
    }
}

struct AppSymbol: View {
    let systemName: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let image = handDrawnImage {
                handDrawnLayer(image)
            } else {
                Image(systemName: systemName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var handDrawnImage: UIImage? {
        HandDrawnSymbol.uiImage(for: systemName, pointSize: size)
    }

    private func handDrawnLayer(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }
}

struct AppSymbolLabel: View {
    let title: String
    let systemName: String
    var symbolSize: CGFloat = 18

    var body: some View {
        Label {
            Text(title)
        } icon: {
            AppSymbol(systemName: systemName, size: symbolSize)
        }
    }
}

struct AppContentUnavailableView: View {
    let title: String
    let systemName: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                AppSymbol(systemName: systemName, size: 48)
            }
        } description: {
            Text(description)
        }
    }
}

#Preview("Hand-drawn and fallback symbols") {
    VStack(spacing: 20) {
        AppSymbolLabel(title: "Reading plan", systemName: "cloud.sun.fill")
        Label("Fallback", systemImage: "sparkles")
        AppContentUnavailableView(
            title: "No books",
            systemName: "books.vertical.fill",
            description: "Add a book to begin."
        )
    }
    .padding()
}
