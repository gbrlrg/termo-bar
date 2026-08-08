import SwiftUI

enum Theme {
    /// Paleta categórica validada (claro / escuro), em ordem fixa: a cor segue o app.
    static let series: [Color] = [
        dynamic(0x2a78d6, 0x3987e5),
        dynamic(0xeb6834, 0xd95926),
        dynamic(0x1baf7a, 0x199e70),
        dynamic(0xeda100, 0xc98500),
        dynamic(0xe87ba4, 0xd55181),
    ]
    static let others = Color.secondary.opacity(0.35)

    // Estado térmico (paleta de status, sempre com ícone e rótulo).
    static let good = dynamic(0x0ca30c, 0x0ca30c)
    static let warning = dynamic(0xfab219, 0xfab219)
    static let serious = dynamic(0xec835a, 0xec835a)
    static let critical = dynamic(0xd03b3b, 0xd03b3b)

    /// Escala de temperatura do chip, do frio ao quente, como no app Tempo.
    private static let temperatureStops: [(Double, NSColor)] = [
        (40, .systemTeal), (58, .systemGreen), (70, .systemYellow), (82, .systemOrange), (95, .systemRed),
    ]

    static func temperatureColor(_ value: Double) -> Color {
        Color(nsColor: nsTemperatureColor(value))
    }

    private static func nsTemperatureColor(_ value: Double) -> NSColor {
        let stops = temperatureStops
        if value <= stops[0].0 { return stops[0].1 }
        for (a, b) in zip(stops, stops.dropFirst()) where value <= b.0 {
            let fraction = (value - a.0) / (b.0 - a.0)
            return a.1.blended(withFraction: fraction, of: b.1) ?? b.1
        }
        return stops[stops.count - 1].1
    }

    /// Gradiente vertical que pinta cada altura da linha com a cor da sua temperatura.
    static func temperatureGradient(_ range: ClosedRange<Double>) -> LinearGradient {
        let span = max(range.upperBound - range.lowerBound, 0.1)
        var stops = [Gradient.Stop(color: temperatureColor(range.lowerBound), location: 0)]
        for (value, _) in temperatureStops where range.contains(value) {
            stops.append(.init(color: temperatureColor(value), location: (value - range.lowerBound) / span))
        }
        stops.append(.init(color: temperatureColor(range.upperBound), location: 1))
        return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
    }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
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
        default: Theme.critical
        }
    }
}
