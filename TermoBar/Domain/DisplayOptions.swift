enum TemperatureUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case celsius, fahrenheit

    var id: Self { self }

    var symbol: String { self == .celsius ? "°C" : "°F" }

    var label: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }

    func convert(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }

    /// Diferenças (amplitude, desvio) não somam os 32 do Fahrenheit.
    func convertDelta(_ celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5
    }

    func toCelsius(_ value: Double) -> Double {
        self == .celsius ? value : (value - 32) * 5 / 9
    }
}

/// Qual leitura representa a temperatura do chip.
enum TemperatureSource: String, CaseIterable, Identifiable, Sendable {
    case average, hottest

    var id: Self { self }

    var label: String { self == .average ? String(localized: "Média do chip") : String(localized: "Ponto mais quente") }

    /// A outra fonte, mostrada como informação secundária.
    var alternate: TemperatureSource { self == .average ? .hottest : .average }
}

enum MenuBarStyle: String, CaseIterable, Identifiable, Sendable {
    case icon, temperature, temperatureAndPower, temperatureAndFan

    var id: Self { self }

    var label: String {
        switch self {
        case .icon: String(localized: "Somente ícone")
        case .temperature: String(localized: "Somente temperatura")
        case .temperatureAndPower: String(localized: "Temperatura e watts")
        case .temperatureAndFan: String(localized: "Temperatura e velocidade do ventilador")
        }
    }

    var showsTemperature: Bool { self != .icon }

    var showsPower: Bool { self == .temperatureAndPower }

    /// Só faz sentido em Macs com ventoinha; nos outros, vale como `temperature`.
    var showsFan: Bool { self == .temperatureAndFan }
}
