import Foundation
import Testing

/// Rótulos, identificadores e conversões simples dos tipos do domínio.
struct DomainBasicsTests {
    @Test func everyCaseHasItsOwnLabel() {
        #expect(Set(TemperatureUnit.allCases.map(\.label)).count == TemperatureUnit.allCases.count)
        #expect(Set(TemperatureSource.allCases.map(\.label)).count == TemperatureSource.allCases.count)
        #expect(Set(MenuBarStyle.allCases.map(\.label)).count == MenuBarStyle.allCases.count)
        #expect(Set(TimeRange.allCases.map(\.label)).count == TimeRange.allCases.count)
        #expect(Set(ThermalPressure.allCases.map(\.label)).count == ThermalPressure.allCases.count)
        #expect(TemperatureUnit.celsius.label == "Celsius (°C)")
        #expect(TimeRange.hour.label == "1 h")
    }

    @Test func identifiersAreTheCasesThemselves() {
        #expect(TemperatureUnit.allCases.map(\.id) == TemperatureUnit.allCases)
        #expect(TemperatureSource.allCases.map(\.id) == TemperatureSource.allCases)
        #expect(MenuBarStyle.allCases.map(\.id) == MenuBarStyle.allCases)
        #expect(TimeRange.allCases.map(\.id) == TimeRange.allCases)
    }

    @Test func unitSymbolsAndRoundTrip() {
        #expect(TemperatureUnit.celsius.symbol == "°C")
        #expect(TemperatureUnit.fahrenheit.symbol == "°F")
        #expect(TemperatureUnit.celsius.convertDelta(10) == 10)
        #expect(TemperatureUnit.celsius.toCelsius(42) == 42)
        #expect(TemperatureUnit.fahrenheit.toCelsius(TemperatureUnit.fahrenheit.convert(37)) == 37)
        #expect(TemperatureSource.hottest.alternate == .average)
    }

    @Test func menuBarStylesShowTheirValues() {
        #expect(MenuBarStyle.temperature.showsTemperature)
        #expect(!MenuBarStyle.temperature.showsPower && !MenuBarStyle.temperature.showsFan)
        #expect(!MenuBarStyle.icon.showsPower && !MenuBarStyle.icon.showsFan)
    }

    @Test func rangesUseMinuteSummariesAboveAnHour() {
        #expect(TimeRange.allCases.map(\.seconds) == [900, 3600, 86400, 604_800])
        #expect(TimeRange.allCases.map(\.binSize) == [15, 60, 900, 3600])
        #expect(TimeRange.allCases.filter(\.usesMinuteSummaries) == [.day, .week])
        // Cada barra cabe um número inteiro de vezes no período.
        for range in TimeRange.allCases {
            #expect(range.seconds.truncatingRemainder(dividingBy: range.binSize) == 0)
        }
    }

    @Test func pressureLevelsAreOrderedAndThrottleFromHeavy() {
        #expect(ThermalPressure.allCases == ThermalPressure.allCases.sorted())
        #expect(ThermalPressure.allCases.filter(\.isThrottling) == [.heavy, .critical, .sleeping])
        #expect(ThermalPressure.moderate < .heavy)
        #expect(ThermalPressure(rawValue: 2) == .heavy)
        #expect(ThermalPressure(rawValue: 9) == nil)
    }

    @Test func fanSpinsFromTheThreshold() {
        #expect(Fan(id: 0, rpm: 100, minimum: 1200, maximum: 6000).isSpinning)
        #expect(!Fan(id: 0, rpm: 99, minimum: 1200, maximum: 6000).isSpinning)
    }

    @Test func appIDConventions() {
        #expect(AppID.process(named: "node") == "proc:node")
        #expect(AppID.isProcess("proc:node"))
        #expect(!AppID.isProcess("com.apple.Safari"))
        #expect(AppID.isProcess(AppID.unknownProcess))
        #expect(!AppID.isProcess(AppID.others))
        #expect(AppID.othersName == String(localized: "Outros"))
    }

    @Test func powerArithmetic() {
        var power = Power(cpu: 1, gpu: 2)
        power += Power(cpu: 0.5, gpu: 0.5)
        #expect(power == Power(cpu: 1.5, gpu: 2.5))
        #expect(power.total == 4)
        #expect(power * 2 == Power(cpu: 3, gpu: 5))
        #expect(power / 2 == Power(cpu: 0.75, gpu: 1.25))
        #expect(Power.zero.total == 0)
    }

    @Test func clampsIntoTheRange() {
        #expect(5.clamped(to: 0...3) == 3)
        #expect((-1).clamped(to: 0...3) == 0)
        #expect(2.5.clamped(to: 0...3) == 2.5)
    }

    @Test func settingsTabsHaveTitlesSymbolsAndStableNames() {
        #expect(
            SettingsTab.allCases.map(\.rawValue) == [
                "geral", "barra", "alertas", "sensores", "dados", "precisao", "sobre",
            ])
        #expect(Set(SettingsTab.allCases.map(\.title)).count == SettingsTab.allCases.count)
        #expect(Set(SettingsTab.allCases.map(\.symbol)).count == SettingsTab.allCases.count)
        #expect(SettingsTab(rawValue: "sensores") == .sensors)
        #expect(SettingsTab(rawValue: "inexistente") == nil)
    }
}
