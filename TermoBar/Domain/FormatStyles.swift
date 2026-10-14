import Foundation

/// Temperatura guardada em °C, exibida na unidade escolhida: "79 °C", "174,2 °F" ou "79°".
struct TemperatureFormatStyle: FormatStyle {
    enum Symbol: Codable, Hashable { case unit, degree, none }

    var unit: TemperatureUnit
    var fractionDigits: Int
    var symbol: Symbol

    func format(_ celsius: Double) -> String {
        let value = unit.convert(celsius).formatted(.number.precision(.fractionLength(fractionDigits)))
        switch symbol {
        case .unit: return "\(value) \(unit.symbol)"
        case .degree: return "\(value)°"
        case .none: return value
        }
    }
}

/// Potência com casas decimais conforme a grandeza: "0,05 W", "2,4 W", "17 W".
struct WattsFormatStyle: FormatStyle {
    func format(_ watts: Double) -> String {
        let fractionDigits = watts < 0.1 ? 2 : watts < 10 ? 1 : 0
        return "\(watts.formatted(.number.precision(.fractionLength(fractionDigits)))) W"
    }
}

extension FormatStyle where Self == WattsFormatStyle {
    static var watts: WattsFormatStyle { WattsFormatStyle() }
}

/// Rotação de ventoinha, inteira e com separador de milhar: "2.503 rpm".
struct RPMFormatStyle: FormatStyle {
    func format(_ rpm: Double) -> String {
        "\(rpm.formatted(.number.precision(.fractionLength(0)))) rpm"
    }
}

extension FormatStyle where Self == RPMFormatStyle {
    static var rpm: RPMFormatStyle { RPMFormatStyle() }
}
