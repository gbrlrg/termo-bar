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
    case temperature, temperatureAndPower, temperatureAndFan, iconAndTemperature, icon

    var id: Self { self }

    var label: String {
        switch self {
        case .temperature: String(localized: "Temperatura")
        case .temperatureAndPower: String(localized: "Temperatura e watts")
        case .temperatureAndFan: String(localized: "Temperatura e ventoinha")
        case .iconAndTemperature: String(localized: "Ícone e temperatura")
        case .icon: String(localized: "Só ícone")
        }
    }

    var showsIcon: Bool { self == .icon || self == .iconAndTemperature }

    var showsTemperature: Bool { self != .icon }

    var showsPower: Bool { self == .temperatureAndPower }

    /// Só faz sentido em Macs com ventoinha; nos outros, vale como `temperature`.
    var showsFan: Bool { self == .temperatureAndFan }
}
