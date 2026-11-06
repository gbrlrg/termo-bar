import Foundation
import Testing

struct MenuBarContentTests {
    private typealias Segment = MenuBarContent.Segment

    private func options(
        _ style: MenuBarStyle = .temperature, compact: Bool = false, threshold: Double = 70, icons: Bool = false
    ) -> MenuBarContent.Options {
        MenuBarContent.Options(
            style: style, compactWhenCool: compact, compactThreshold: threshold, showValueIcons: icons,
            unitSymbol: "°C")
    }

    private func reading(
        _ temperature: Double? = 80, fan: Double? = 2500, power: Double? = 7.5, hasFans: Bool = true
    ) -> MenuBarContent.Reading {
        MenuBarContent.Reading(temperature: temperature, fanSpeed: fan, power: power, hasFans: hasFans)
    }

    private func segments(_ reading: MenuBarContent.Reading, _ options: MenuBarContent.Options) -> [Segment] {
        MenuBarContent.segments(reading, options: options) { "\(Int($0)) °C" }
    }

    @Test func temperatureLosesTheSpaceToFitTheBar() {
        #expect(segments(reading(), options()) == [Segment(symbol: nil, text: "80°C")])
    }

    @Test func iconOnlyShowsNoValues() {
        #expect(segments(reading(), options(.icon)).isEmpty)
    }

    @Test func noReadingYetShowsDashes() {
        #expect(segments(reading(nil), options()) == [Segment(symbol: nil, text: "--°C")])
    }

    @Test func compactModeHidesValuesWhileCool() {
        #expect(segments(reading(60), options(compact: true)).isEmpty)
        #expect(segments(reading(nil), options(compact: true)).isEmpty)
        #expect(segments(reading(70), options(compact: true)) == [Segment(symbol: nil, text: "70°C")])
        #expect(
            MenuBarContent.effectiveStyle(reading(60), options: options(.temperatureAndPower)) == .temperatureAndPower)
    }

    @Test func addsPowerOrFanWithTheirIcons() {
        #expect(
            segments(reading(), options(.temperatureAndPower, icons: true)) == [
                Segment(symbol: MenuBarContent.Symbol.temperature, text: "80°C"),
                Segment(symbol: MenuBarContent.Symbol.power, text: 7.5.formatted(.watts)),
            ])
        #expect(
            segments(reading(), options(.temperatureAndFan, icons: true)) == [
                Segment(symbol: MenuBarContent.Symbol.temperature, text: "80°C"),
                Segment(symbol: MenuBarContent.Symbol.fan, text: 2500.0.formatted(.rpm)),
            ])
    }

    @Test func missingSecondValueShowsOnlyTheTemperature() {
        #expect(segments(reading(power: nil), options(.temperatureAndPower)).count == 1)
        #expect(segments(reading(fan: nil), options(.temperatureAndFan)).count == 1)
    }

    @Test func fanStyleFallsBackToTemperatureWithoutFans() {
        let fanless = reading(hasFans: false)
        #expect(MenuBarContent.effectiveStyle(fanless, options: options(.temperatureAndFan)) == .temperature)
        #expect(segments(fanless, options(.temperatureAndFan)) == [Segment(symbol: nil, text: "80°C")])
    }
}
