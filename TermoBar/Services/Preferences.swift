import Foundation
import Observation

/// Preferências do usuário, gravadas no UserDefaults. Temperaturas sempre em °C internamente.
@MainActor @Observable
final class Preferences {
    static let sampleIntervalRange: ClosedRange<Double> = 1...60
    static let retentionDaysRange: ClosedRange<Int> = 1...365
    static let temperatureLimitRange: ClosedRange<Double> = 30...120
    static let appWattsRange: ClosedRange<Double> = 1...60
    static let appMinutesRange: ClosedRange<Double> = 2...60

    private enum Key: String {
        case unit, decimals, source, menuBarStyle, compactWhenCool, compactThreshold, colorWhenHot
        case sampleInterval, retentionDays
        case alertTemperature, alertTemperatureLimit, alertThrottling, alertAppPower, alertAppWatts, alertAppMinutes
    }

    private let defaults: UserDefaults

    var unit: TemperatureUnit { didSet { save(unit.rawValue, .unit) } }
    var decimals: Int { didSet { save(decimals, .decimals) } }
    var source: TemperatureSource { didSet { save(source.rawValue, .source) } }
    var menuBarStyle: MenuBarStyle { didSet { save(menuBarStyle.rawValue, .menuBarStyle) } }
    /// Na barra, mostra só o ícone enquanto a temperatura estiver abaixo do limite.
    var compactWhenCool: Bool { didSet { save(compactWhenCool, .compactWhenCool) } }
    var compactThreshold: Double { didSet { save(compactThreshold, .compactThreshold) } }
    var colorWhenHot: Bool { didSet { save(colorWhenHot, .colorWhenHot) } }
    /// Intervalo entre registros no histórico (s).
    var sampleInterval: Double { didSet { save(sampleInterval, .sampleInterval) } }
    var retentionDays: Int { didSet { save(retentionDays, .retentionDays) } }

    var alertTemperature: Bool { didSet { save(alertTemperature, .alertTemperature) } }
    var alertTemperatureLimit: Double { didSet { save(alertTemperatureLimit, .alertTemperatureLimit) } }
    var alertThrottling: Bool { didSet { save(alertThrottling, .alertThrottling) } }
    var alertAppPower: Bool { didSet { save(alertAppPower, .alertAppPower) } }
    var alertAppWatts: Double { didSet { save(alertAppWatts, .alertAppWatts) } }
    var alertAppMinutes: Double { didSet { save(alertAppMinutes, .alertAppMinutes) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.unit.rawValue:
                (Locale.current.measurementSystem == .us
                ? TemperatureUnit.fahrenheit : .celsius).rawValue,
            Key.decimals.rawValue: 0,
            Key.source.rawValue: TemperatureSource.average.rawValue,
            Key.menuBarStyle.rawValue: MenuBarStyle.temperature.rawValue,
            Key.compactWhenCool.rawValue: false,
            Key.compactThreshold.rawValue: 70.0,
            Key.colorWhenHot.rawValue: false,
            Key.sampleInterval.rawValue: 5.0,
            Key.retentionDays.rawValue: 30,
            Key.alertTemperature.rawValue: false,
            Key.alertTemperatureLimit.rawValue: 95.0,
            Key.alertThrottling.rawValue: true,
            Key.alertAppPower.rawValue: false,
            Key.alertAppWatts.rawValue: 8.0,
            Key.alertAppMinutes.rawValue: 10.0,
        ])

        // Valores fora da faixa (editados à mão com `defaults write`) são trazidos para dentro dela.
        unit = TemperatureUnit(rawValue: defaults.string(forKey: Key.unit.rawValue) ?? "") ?? .celsius
        decimals = defaults.integer(forKey: Key.decimals.rawValue).clamped(to: 0...1)
        source = TemperatureSource(rawValue: defaults.string(forKey: Key.source.rawValue) ?? "") ?? .average
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: Key.menuBarStyle.rawValue) ?? "") ?? .temperature
        compactWhenCool = defaults.bool(forKey: Key.compactWhenCool.rawValue)
        compactThreshold = defaults.double(forKey: Key.compactThreshold.rawValue).clamped(
            to: Self.temperatureLimitRange)
        colorWhenHot = defaults.bool(forKey: Key.colorWhenHot.rawValue)
        sampleInterval = defaults.double(forKey: Key.sampleInterval.rawValue).clamped(to: Self.sampleIntervalRange)
        retentionDays = defaults.integer(forKey: Key.retentionDays.rawValue).clamped(to: Self.retentionDaysRange)
        alertTemperature = defaults.bool(forKey: Key.alertTemperature.rawValue)
        alertTemperatureLimit = defaults.double(forKey: Key.alertTemperatureLimit.rawValue)
            .clamped(to: Self.temperatureLimitRange)
        alertThrottling = defaults.bool(forKey: Key.alertThrottling.rawValue)
        alertAppPower = defaults.bool(forKey: Key.alertAppPower.rawValue)
        alertAppWatts = defaults.double(forKey: Key.alertAppWatts.rawValue).clamped(to: Self.appWattsRange)
        alertAppMinutes = defaults.double(forKey: Key.alertAppMinutes.rawValue).clamped(to: Self.appMinutesRange)
    }

    var alertConfiguration: AlertConfiguration {
        AlertConfiguration(
            temperatureLimit: alertTemperature ? alertTemperatureLimit : nil,
            throttling: alertThrottling,
            appPower: alertAppPower
                ? AlertConfiguration.AppPowerLimit(watts: alertAppWatts, window: alertAppMinutes * 60) : nil)
    }

    // MARK: - Formatação

    /// "79 °C", "174,2 °F"; sem `symbol`, só o número.
    func format(_ celsius: Double, decimals: Int? = nil, symbol: Bool = true) -> String {
        celsius.formatted(
            TemperatureFormatStyle(
                unit: unit, fractionDigits: decimals ?? self.decimals, symbol: symbol ? .unit : .none))
    }

    /// "79°" (para eixos e textos compactos)
    func short(_ celsius: Double) -> String {
        celsius.formatted(TemperatureFormatStyle(unit: unit, fractionDigits: 0, symbol: .degree))
    }

    private func save(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
