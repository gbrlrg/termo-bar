import Foundation
import Observation

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: Self { self }
    var symbol: String { self == .celsius ? "°C" : "°F" }
    var label: String { self == .celsius ? "Celsius (°C)" : "Fahrenheit (°F)" }

    func convert(_ celsius: Double) -> Double { self == .celsius ? celsius : celsius * 9 / 5 + 32 }
    /// Diferenças (amplitude, desvio) não somam os 32 do Fahrenheit.
    func convertDelta(_ celsius: Double) -> Double { self == .celsius ? celsius : celsius * 9 / 5 }
    func toCelsius(_ value: Double) -> Double { self == .celsius ? value : (value - 32) * 5 / 9 }
}

enum TemperatureSource: String, CaseIterable, Identifiable {
    case average, hottest
    var id: Self { self }
    var label: String { self == .average ? "Média do chip" : "Ponto mais quente" }
}

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case temperature, temperatureAndPower, iconAndTemperature, icon
    var id: Self { self }
    var label: String {
        switch self {
        case .temperature: "Temperatura"
        case .temperatureAndPower: "Temperatura e watts"
        case .iconAndTemperature: "Ícone e temperatura"
        case .icon: "Só ícone"
        }
    }
}

/// Preferências do usuário, gravadas no UserDefaults. Temperaturas sempre em °C internamente.
@MainActor @Observable
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    var unit: TemperatureUnit { didSet { defaults.set(unit.rawValue, forKey: "unit") } }
    var decimals: Int { didSet { defaults.set(decimals, forKey: "decimals") } }
    var source: TemperatureSource { didSet { defaults.set(source.rawValue, forKey: "source") } }
    var menuBarStyle: MenuBarStyle { didSet { defaults.set(menuBarStyle.rawValue, forKey: "menuBarStyle") } }
    /// Na barra, mostra só o ícone enquanto a temperatura estiver abaixo do limite.
    var compactWhenCool: Bool { didSet { defaults.set(compactWhenCool, forKey: "compactWhenCool") } }
    var compactThreshold: Double { didSet { defaults.set(compactThreshold, forKey: "compactThreshold") } }
    var colorWhenHot: Bool { didSet { defaults.set(colorWhenHot, forKey: "colorWhenHot") } }
    var sampleInterval: Double { didSet { defaults.set(sampleInterval, forKey: "sampleInterval") } }
    var retentionDays: Int { didSet { defaults.set(retentionDays, forKey: "retentionDays") } }

    var alertTemperature: Bool { didSet { defaults.set(alertTemperature, forKey: "alertTemperature") } }
    var alertTemperatureLimit: Double { didSet { defaults.set(alertTemperatureLimit, forKey: "alertTemperatureLimit") } }
    var alertThrottling: Bool { didSet { defaults.set(alertThrottling, forKey: "alertThrottling") } }
    var alertAppPower: Bool { didSet { defaults.set(alertAppPower, forKey: "alertAppPower") } }
    var alertAppWatts: Double { didSet { defaults.set(alertAppWatts, forKey: "alertAppWatts") } }
    var alertAppMinutes: Double { didSet { defaults.set(alertAppMinutes, forKey: "alertAppMinutes") } }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "unit": Locale.current.measurementSystem == .us ? TemperatureUnit.fahrenheit.rawValue : TemperatureUnit.celsius.rawValue,
            "decimals": 0,
            "source": TemperatureSource.average.rawValue,
            "menuBarStyle": MenuBarStyle.temperature.rawValue,
            "compactWhenCool": false,
            "compactThreshold": 70.0,
            "colorWhenHot": false,
            "sampleInterval": 5.0,
            "retentionDays": 30,
            "alertTemperature": false,
            "alertTemperatureLimit": 95.0,
            "alertThrottling": true,
            "alertAppPower": false,
            "alertAppWatts": 8.0,
            "alertAppMinutes": 10.0,
        ])
        unit = TemperatureUnit(rawValue: d.string(forKey: "unit") ?? "") ?? .celsius
        decimals = d.integer(forKey: "decimals")
        source = TemperatureSource(rawValue: d.string(forKey: "source") ?? "") ?? .average
        menuBarStyle = MenuBarStyle(rawValue: d.string(forKey: "menuBarStyle") ?? "") ?? .temperature
        compactWhenCool = d.bool(forKey: "compactWhenCool")
        compactThreshold = d.double(forKey: "compactThreshold")
        colorWhenHot = d.bool(forKey: "colorWhenHot")
        sampleInterval = d.double(forKey: "sampleInterval")
        retentionDays = d.integer(forKey: "retentionDays")
        alertTemperature = d.bool(forKey: "alertTemperature")
        alertTemperatureLimit = d.double(forKey: "alertTemperatureLimit")
        alertThrottling = d.bool(forKey: "alertThrottling")
        alertAppPower = d.bool(forKey: "alertAppPower")
        alertAppWatts = d.double(forKey: "alertAppWatts")
        alertAppMinutes = d.double(forKey: "alertAppMinutes")
    }

    // MARK: - Formatação

    /// "79 °C", "174,2 °F"
    func format(_ celsius: Double, decimals: Int? = nil, symbol: Bool = true) -> String {
        let places = decimals ?? self.decimals
        let value = unit.convert(celsius).formatted(.number.precision(.fractionLength(places)))
        return symbol ? "\(value) \(unit.symbol)" : value
    }

    /// "79°" (para eixos e textos compactos)
    func short(_ celsius: Double) -> String {
        "\(unit.convert(celsius).formatted(.number.precision(.fractionLength(0))))°"
    }
}

func formatWatts(_ value: Double) -> String {
    let places = value < 0.1 ? 2 : value < 10 ? 1 : 0
    return "\(value.formatted(.number.precision(.fractionLength(places)))) W"
}
