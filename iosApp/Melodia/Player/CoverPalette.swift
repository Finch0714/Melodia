import Foundation
import SwiftUI
import UIKit

final class PaletteMemoryCache {
    static let shared = PaletteMemoryCache()

    private let cache = NSCache<NSNumber, UIColor>()

    private init() {
        cache.countLimit = 150
    }

    func color(for trackID: Int64) -> UIColor? {
        cache.object(forKey: NSNumber(value: trackID))
    }

    func put(_ color: UIColor, for trackID: Int64) {
        cache.setObject(color, forKey: NSNumber(value: trackID))
    }
}

enum CoverPalette {
    static let fallback = UIColor(red: CGFloat(0x33) / 255, green: CGFloat(0x33) / 255, blue: CGFloat(0x33) / 255, alpha: 1)

    static func color(for url: URL) async -> UIColor? {
        guard let image = await RemoteImageCache.shared.image(for: url.melodiaImageURL(pixels: 320)) else {
            return nil
        }
        return await Task.detached(priority: .utility) {
            extract(from: image)
        }.value
    }

    static func darkened(_ color: UIColor, amount: CGFloat) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 1
        guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return Color(uiColor: color)
        }
        let darkened = UIColor(
            hue: hue,
            saturation: saturation,
            brightness: max(0, brightness * (1 - amount)),
            alpha: alpha
        )
        return Color(uiColor: darkened)
    }

    // MARK: - Extraction

    private struct Swatch {
        let color: UIColor
        let population: Int
        let hsl: HSL
        var chroma: Double { hsl.chroma }
    }

    private struct HSL {
        let hue: Double
        let saturation: Double
        let lightness: Double
        let chroma: Double
    }

    private static func extract(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 64
        let height = 64
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * bytesPerPixel)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var histogram: [Int: (count: Int, r: Double, g: Double, b: Double)] = [:]
        for offset in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
            let alpha = Int(buffer[offset + 3])
            guard alpha >= 125 else { continue }
            let r = Int(buffer[offset])
            let g = Int(buffer[offset + 1])
            let b = Int(buffer[offset + 2])
            guard !(r > 250 && g > 250 && b > 250) else { continue }

            let key = (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3)
            var entry = histogram[key] ?? (0, 0, 0, 0)
            entry.count += 1
            entry.r += Double(r)
            entry.g += Double(g)
            entry.b += Double(b)
            histogram[key] = entry
        }

        let swatches: [Swatch] = histogram.values.compactMap { entry in
            guard entry.count > 0 else { return nil }
            let r = entry.r / Double(entry.count) / 255
            let g = entry.g / Double(entry.count) / 255
            let b = entry.b / Double(entry.count) / 255
            let hsl = toHSL(r: r, g: g, b: b)
            return Swatch(
                color: UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1),
                population: entry.count,
                hsl: hsl
            )
        }
        guard !swatches.isEmpty else { return nil }

        let meaningfulChroma = 0.06
        if swatches.allSatisfy({ $0.chroma < meaningfulChroma }) {
            return grayscaleBase(from: swatches)
        }

        return pickBaseColor(from: swatches)
    }

    private static func pickBaseColor(from swatches: [Swatch]) -> UIColor {
        let candidates = swatches.filter { $0.population > 0 && $0.hsl.lightness >= 0.1 && $0.hsl.lightness < 0.9 }
        guard !candidates.isEmpty else { return fallback }

        let (neutral, chromatic) = candidates.reduce(into: ([Swatch](), [Swatch]())) { result, swatch in
            let threshold = 0.13 * min(1, swatch.hsl.lightness / 0.5)
            if swatch.chroma < threshold {
                result.0.append(swatch)
            } else {
                result.1.append(swatch)
            }
        }
        let neutralArea = neutral.reduce(0) { $0 + $1.population }

        var bestGroup: [Swatch] = []
        var bestArea = 0
        for seed in chromatic {
            let group = chromatic.filter { hueDistance(seed.hsl.hue, $0.hsl.hue) <= 20.0 / 360.0 }
            let area = group.reduce(0) { $0 + $1.population }
            if area > bestArea {
                bestArea = area
                bestGroup = group
            }
        }

        if bestGroup.isEmpty || Double(neutralArea) >= Double(bestArea) * 1.6 {
            guard !neutral.isEmpty, neutralArea > 0 else { return fallback }
            let lightness = neutral.reduce(0.0) { $0 + $1.hsl.lightness * Double($1.population) } / Double(neutralArea)
            if let hue = weightedMeanHue(neutral) {
                return normalizedColor(hue: hue, chroma: 0.06, lightness: lightness)
            }
            let gray = min(max(lightness, 0.2), 0.5)
            return UIColor(red: CGFloat(gray), green: CGFloat(gray), blue: CGFloat(gray), alpha: 1)
        }

        let chosen = bestGroup.max { lhs, rhs in
            var lhsDarkness = 1.0
            var rhsDarkness = 1.0
            for _ in 0..<2 {
                lhsDarkness *= 1 - lhs.hsl.lightness
                rhsDarkness *= 1 - rhs.hsl.lightness
            }
            return Double(lhs.population) * lhsDarkness < Double(rhs.population) * rhsDarkness
        } ?? bestGroup[0]

        return normalizedColor(
            hue: chosen.hsl.hue,
            chroma: min(max(chosen.chroma, 0.15), 0.30),
            lightness: chosen.hsl.lightness
        )
    }

    private static func grayscaleBase(from swatches: [Swatch]) -> UIColor {
        guard let dominant = swatches.max(by: { $0.population < $1.population }) else {
            return fallback
        }
        let gray = min(max(dominant.hsl.lightness, 0.15), 0.35)
        return UIColor(red: CGFloat(gray), green: CGFloat(gray), blue: CGFloat(gray), alpha: 1)
    }

    private static func normalizedColor(hue: Double, chroma: Double, lightness: Double) -> UIColor {
        let l = min(max(lightness, 0.2), 0.5)
        let denominator = 1 - abs(2 * l - 1)
        let s = denominator > 0 ? min(max(chroma / denominator, 0), 1) : 0
        return hslToUIColor(hue: hue, saturation: s, lightness: l)
    }

    private static func hueDistance(_ lhs: Double, _ rhs: Double) -> Double {
        let distance = abs(lhs - rhs).truncatingRemainder(dividingBy: 1)
        return min(distance, 1 - distance)
    }

    private static func weightedMeanHue(_ swatches: [Swatch]) -> Double? {
        var x = 0.0
        var y = 0.0
        for swatch in swatches {
            let weight = Double(swatch.population) * swatch.chroma
            let angle = swatch.hsl.hue * 2 * Double.pi
            x += weight * cos(angle)
            y += weight * sin(angle)
        }
        if x == 0 && y == 0 { return nil }
        var hue = atan2(y, x) / (2 * Double.pi)
        if hue < 0 { hue += 1 }
        return hue
    }

    private static func toHSL(r: Double, g: Double, b: Double) -> HSL {
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let lightness = (maxValue + minValue) / 2
        let chroma = maxValue - minValue
        let saturation = chroma == 0 ? 0 : chroma / (1 - abs(2 * lightness - 1))
        var hue = 0.0
        if chroma > 0 {
            if maxValue == r {
                hue = (g - b) / chroma
            } else if maxValue == g {
                hue = (b - r) / chroma + 2
            } else {
                hue = (r - g) / chroma + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return HSL(hue: hue, saturation: saturation, lightness: lightness, chroma: chroma)
    }

    private static func hslToUIColor(hue: Double, saturation: Double, lightness: Double) -> UIColor {
        if saturation <= 0 {
            return UIColor(red: CGFloat(lightness), green: CGFloat(lightness), blue: CGFloat(lightness), alpha: 1)
        }
        let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q
        let r = hueToRGB(p: p, q: q, t: hue + 1.0 / 3.0)
        let g = hueToRGB(p: p, q: q, t: hue)
        let b = hueToRGB(p: p, q: q, t: hue - 1.0 / 3.0)
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
    }

    private static func hueToRGB(p: Double, q: Double, t: Double) -> Double {
        var value = t
        if value < 0 { value += 1 }
        if value > 1 { value -= 1 }
        if value < 1.0 / 6.0 { return p + (q - p) * 6 * value }
        if value < 1.0 / 2.0 { return q }
        if value < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - value) * 6 }
        return p
    }
}