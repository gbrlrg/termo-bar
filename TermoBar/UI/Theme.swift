import SwiftUI

enum Theme {
    /// Paleta categórica validada (claro / escuro), em ordem fixa: a cor segue o app.
    static let series: [Color] = [
        dynamic(light: 0x2a78d6, dark: 0x3987e5),
        dynamic(light: 0xeb6834, dark: 0xd95926),
        dynamic(light: 0x1baf7a, dark: 0x199e70),
        dynamic(light: 0xeda100, dark: 0xc98500),
        dynamic(light: 0xe87ba4, dark: 0xd55181),
    ]
    static let others = Color.secondary.opacity(0.35)

    // Estado térmico (paleta de status, sempre com ícone e rótulo).
    static let good = dynamic(light: 0x0ca30c, dark: 0x0ca30c)
    static let warning = dynamic(light: 0xfab219, dark: 0xfab219)
    static let serious = dynamic(light: 0xec835a, dark: 0xec835a)
    static let critical = dynamic(light: 0xd03b3b, dark: 0xd03b3b)

    /// Escala de temperatura do chip, do frio ao quente, como no app Tempo.
    private static let temperatureStops: [(celsius: Double, color: NSColor)] = [
        (40, .systemTeal), (58, .systemGreen), (70, .systemYellow), (82, .systemOrange), (95, .systemRed),
    ]

    /// Cor da série de um app com cor própria; `others` para o resto.
    static func seriesColor(slot: Int?) -> Color {
        slot.map { series[$0 % series.count] } ?? others
    }

    static func temperatureColor(_ celsius: Double) -> Color {
        Color(nsColor: nsTemperatureColor(celsius))
    }

    /// Gradiente vertical que pinta cada altura da linha com a cor da sua temperatura.
    static func temperatureGradient(_ range: ClosedRange<Double>) -> LinearGradient {
        let span = max(range.upperBound - range.lowerBound, 0.1)
        var stops = [Gradient.Stop(color: temperatureColor(range.lowerBound), location: 0)]
        for stop in temperatureStops where range.contains(stop.celsius) {
            stops.append(
                .init(color: temperatureColor(stop.celsius), location: (stop.celsius - range.lowerBound) / span))
        }
        stops.append(.init(color: temperatureColor(range.upperBound), location: 1))
        return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
    }

    private static func nsTemperatureColor(_ celsius: Double) -> NSColor {
        let stops = temperatureStops
        guard let first = stops.first, let last = stops.last else { return .labelColor }
        if celsius <= first.celsius { return first.color }
        for (lower, upper) in zip(stops, stops.dropFirst()) where celsius <= upper.celsius {
            let fraction = (celsius - lower.celsius) / (upper.celsius - lower.celsius)
            return lower.color.blended(withFraction: fraction, of: upper.color) ?? upper.color
        }
        return last.color
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
                return NSColor(
                    srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
                    blue: CGFloat(hex & 0xff) / 255, alpha: 1)
            })
    }
}

extension ThermalPressure {
    var color: Color {
        switch self {
        case .nominal: Theme.good
        case .moderate: Theme.warning
        case .heavy: Theme.serious
        case .critical, .sleeping: Theme.critical
        }
    }

    var symbol: String {
        switch self {
        case .nominal: "checkmark.circle.fill"
        case .moderate: "thermometer.medium"
        case .heavy: "flame.fill"
        case .critical, .sleeping: "exclamationmark.triangle.fill"
        }
    }
}
