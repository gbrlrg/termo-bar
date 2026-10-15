import Foundation
import Testing

struct FormattingTests {
    @Test func convertsUnits() {
        #expect(TemperatureUnit.fahrenheit.convert(100) == 212)
        #expect(TemperatureUnit.fahrenheit.convertDelta(10) == 18)
        #expect(TemperatureUnit.fahrenheit.toCelsius(212) == 100)
        #expect(TemperatureUnit.celsius.convert(42) == 42)
    }

    @Test func formatsTemperature() {
        let celsius = TemperatureFormatStyle(unit: .celsius, fractionDigits: 0, symbol: .unit)
        #expect(celsius.format(79.4) == "79 °C")
        #expect(TemperatureFormatStyle(unit: .fahrenheit, fractionDigits: 0, symbol: .degree).format(100) == "212°")
        #expect(TemperatureFormatStyle(unit: .celsius, fractionDigits: 0, symbol: .none).format(80) == "80")
    }

    @Test func formatsWattsByMagnitude() {
        #expect(0.05.formatted(.watts).hasSuffix(" W"))
        #expect(17.4.formatted(.watts) == "17 W")
    }

    @Test func formatsRPMAsWholeNumber() {
        #expect(0.0.formatted(.rpm) == "0 rpm")
        #expect(812.6.formatted(.rpm) == "813 rpm")
    }

    @Test func menuBarStyleFlags() {
        #expect(!MenuBarStyle.icon.showsTemperature)
        #expect(MenuBarStyle.temperatureAndPower.showsPower)
        #expect(MenuBarStyle.temperatureAndFan.showsFan && !MenuBarStyle.temperatureAndFan.showsPower)
        #expect(TemperatureSource.average.alternate == .hottest)
    }
}
