import Foundation
import Testing

@MainActor
struct PreferencesTests {
    private let suiteName = "termobar-tests-\(UUID().uuidString)"

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    @Test func usesDefaultsOnFirstLaunch() throws {
        let preferences = Preferences(defaults: try makeDefaults())
        #expect(preferences.decimals == 0)
        #expect(preferences.source == .average)
        #expect(preferences.sampleInterval == 5)
        #expect(preferences.retentionDays == 30)
        #expect(preferences.alertThrottling)
        #expect(!preferences.alertTemperature)
    }

    @Test func persistsChanges() throws {
        let defaults = try makeDefaults()
        let preferences = Preferences(defaults: defaults)
        preferences.unit = .fahrenheit
        preferences.menuBarStyle = .icon
        preferences.alertAppWatts = 12

        let reloaded = Preferences(defaults: defaults)
        #expect(reloaded.unit == .fahrenheit)
        #expect(reloaded.menuBarStyle == .icon)
        #expect(reloaded.alertAppWatts == 12)
    }

    @Test func clampsTamperedValues() throws {
        let defaults = try makeDefaults()
        defaults.set(0, forKey: "sampleInterval")
        defaults.set(-5, forKey: "retentionDays")
        defaults.set(7, forKey: "decimals")
        defaults.set(500.0, forKey: "alertTemperatureLimit")
        defaults.set("kelvin", forKey: "unit")

        let preferences = Preferences(defaults: defaults)

        #expect(preferences.sampleInterval == Preferences.sampleIntervalRange.lowerBound)
        #expect(preferences.retentionDays == Preferences.retentionDaysRange.lowerBound)
        #expect(preferences.decimals == 1)
        #expect(preferences.alertTemperatureLimit == Preferences.temperatureLimitRange.upperBound)
        #expect(preferences.unit == .celsius)
    }

    @Test func buildsAlertConfiguration() throws {
        let preferences = Preferences(defaults: try makeDefaults())
        preferences.alertTemperature = true
        preferences.alertTemperatureLimit = 90
        preferences.alertThrottling = false
        preferences.alertAppPower = true
        preferences.alertAppWatts = 5
        preferences.alertAppMinutes = 3

        let configuration = preferences.alertConfiguration

        #expect(configuration.temperatureLimit == 90)
        #expect(!configuration.throttling)
        #expect(configuration.appPower == AlertConfiguration.AppPowerLimit(watts: 5, window: 180))
    }

    @Test func formatsInTheChosenUnit() throws {
        let preferences = Preferences(defaults: try makeDefaults())
        preferences.unit = .celsius
        preferences.decimals = 0
        #expect(preferences.format(79.4) == "79 °C")
        #expect(preferences.format(80, symbol: false) == "80")
        #expect(preferences.short(80) == "80°")
    }
}
