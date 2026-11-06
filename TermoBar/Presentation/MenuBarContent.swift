import Foundation

/// O que a barra de menus mostra: os valores, cada um com o ícone opcional que vem antes dele.
enum MenuBarContent {
    /// Um valor da barra, com o ícone opcional que vem antes dele.
    struct Segment: Equatable, Sendable {
        var symbol: String?
        var text: String
    }

    enum Symbol {
        static let temperature = "thermometer.medium"
        static let power = "bolt.fill"
        static let fan = "fan.fill"
    }

    /// Preferências da barra (veja `Preferences`).
    struct Options: Sendable {
        var style: MenuBarStyle
        var compactWhenCool: Bool
        /// Abaixo deste valor (°C), o modo compacto mostra só o ícone.
        var compactThreshold: Double
        var showValueIcons: Bool
        /// "°C" ou "°F", para quando ainda não há leitura.
        var unitSymbol: String
    }

    /// Leituras do momento.
    struct Reading: Sendable {
        /// Temperatura conforme a fonte escolhida (°C).
        var temperature: Double?
        var fanSpeed: Double?
        /// Potência somada dos apps (W).
        var power: Double?
        /// O Mac tem ventoinha (o MacBook Air não tem).
        var hasFans: Bool
    }

    /// Estilo efetivo: enquanto estiver frio, o modo compacto mostra só o ícone, e sem ventoinha
    /// o estilo com o ventilador vale como só a temperatura.
    static func effectiveStyle(_ reading: Reading, options: Options) -> MenuBarStyle {
        let isCool = (reading.temperature ?? 0) < options.compactThreshold
        if options.compactWhenCool && isCool { return .icon }
        return options.style.showsFan && !reading.hasFans ? .temperature : options.style
    }

    /// Valores da barra; vazio quando ela mostra só o ícone.
    /// - Parameter formatTemperature: temperatura em °C formatada com as preferências ("79 °C").
    static func segments(
        _ reading: Reading, options: Options, formatTemperature: (Double) -> String
    ) -> [Segment] {
        let style = effectiveStyle(reading, options: options)
        guard style.showsTemperature else { return [] }
        let icons = options.showValueIcons
        let value =
            reading.temperature.map { formatTemperature($0).replacingOccurrences(of: " ", with: "") }
            ?? "--\(options.unitSymbol)"
        var segments = [Segment(symbol: icons ? Symbol.temperature : nil, text: value)]
        if style.showsFan, let rpm = reading.fanSpeed {
            segments.append(Segment(symbol: icons ? Symbol.fan : nil, text: rpm.formatted(.rpm)))
        } else if style.showsPower, let watts = reading.power {
            segments.append(Segment(symbol: icons ? Symbol.power : nil, text: watts.formatted(.watts)))
        }
        return segments
    }
}
