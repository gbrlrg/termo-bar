import Foundation
import Testing

@MainActor
struct ChartDetailsTests {
    private let end = Date(timeIntervalSinceReferenceDate: 3600)

    private func summary(_ history: [Sample], highlighted: Set<String> = ["a"]) -> RangeSummary {
        RangeSummary(range: .quarter, history: history, end: end, highlighted: highlighted) { $0.uppercased() }
    }

    private func preferences() throws -> Preferences {
        let defaults = try #require(UserDefaults(suiteName: "termobar-tests-\(UUID().uuidString)"))
        let preferences = Preferences(defaults: defaults)
        preferences.unit = .celsius
        return preferences
    }

    // MARK: - Energia

    @Test func energyShowsTheAverageWithoutHover() {
        let summary = summary([makeSample(at: 3000, duration: 10, appPower: ["a": Power(cpu: 2, gpu: 1)])])
        #expect(
            ChartDetails.energy(summary, hoverDate: nil) { $0 }
                == String(localized: "média \(3.0.formatted(.watts))"))
        #expect(ChartDetails.energy(self.summary([]), hoverDate: nil) { $0 }.isEmpty)
    }

    @Test func energyOnHoverShowsTheTopAppOfTheBar() {
        let samples = [
            makeSample(at: 3000, duration: 15, appPower: ["a": Power(cpu: 2, gpu: 0), "b": Power(cpu: 1, gpu: 0)])
        ]
        let summary = summary(samples)
        let detail = ChartDetails.energy(summary, hoverDate: Date(timeIntervalSinceReferenceDate: 3001)) {
            $0.uppercased()
        }
        let total = 3.0.formatted(.watts)
        #expect(detail == String(localized: "\("A") \(2.0.formatted(.watts)) de \(total)"))
    }

    @Test func energyOnHoverOfAnEmptyBarShowsTheTotal() {
        let samples = [makeSample(at: 3000, duration: 15, appPower: ["b": Power(cpu: 1, gpu: 0)])]
        let summary = summary(samples, highlighted: [])
        // Só "Outros" na barra: mostra só o total.
        #expect(
            ChartDetails.energy(summary, hoverDate: Date(timeIntervalSinceReferenceDate: 3001)) { $0 }
                == 1.0.formatted(.watts))
        #expect(
            ChartDetails.energy(summary, hoverDate: Date(timeIntervalSinceReferenceDate: 3200)) { $0 }
                == 0.0.formatted(.watts))
    }

    // MARK: - Ventilador

    @Test func fanShowsTheSpinningShareOfThePeriod() {
        let spinning = summary([makeSample(at: 3000, fanSpeed: 0), makeSample(at: 3005, fanSpeed: 2000)])
        #expect(
            ChartDetails.fan(spinning, hoverDate: nil)
                == String(localized: "girando \(0.5.formatted(.percent.precision(.fractionLength(0)))) do tempo"))
        let stopped = summary([makeSample(at: 3000, fanSpeed: 0)])
        #expect(ChartDetails.fan(stopped, hoverDate: nil) == String(localized: "parado no período"))
        #expect(ChartDetails.fan(summary([makeSample(at: 3000)]), hoverDate: nil).isEmpty)
    }

    @Test func fanOnHoverShowsTheNearestReading() {
        let samples = [makeSample(at: 3000, fanSpeed: 2000), makeSample(at: 3005, fanSpeed: 0), makeSample(at: 3010)]
        let summary = summary(samples)
        func detail(_ seconds: TimeInterval) -> String {
            let date = Date(timeIntervalSinceReferenceDate: seconds)
            return ChartDetails.fan(summary, hoverDate: date)
        }
        let format = TimeRange.quarter.hoverDateFormat
        let at = { (seconds: TimeInterval) in Date(timeIntervalSinceReferenceDate: seconds).formatted(format) }
        #expect(detail(3001) == "\(at(3000))  \(2000.0.formatted(.rpm))")
        #expect(detail(3005) == "\(at(3005))  \(String(localized: "parado"))")
        #expect(detail(3011) == "\(at(3010))  \(String(localized: "sem leitura"))")
    }

    // MARK: - Temperatura

    @Test func temperatureShowsTheAverageAndRange() throws {
        let preferences = try preferences()
        let summary = summary([makeSample(at: 3000, temperature: 50), makeSample(at: 3005, temperature: 60)])
        let mean = preferences.format(55, decimals: 1)
        #expect(
            ChartDetails.temperature(summary, hoverDate: nil, preferences: preferences)
                == String(localized: "média \(mean) · \(preferences.short(50))–\(preferences.short(60))"))
        #expect(ChartDetails.temperature(self.summary([]), hoverDate: nil, preferences: preferences).isEmpty)
    }

    @Test func temperatureOnHoverUsesTheChosenSource() throws {
        let preferences = try preferences()
        preferences.source = .hottest
        let summary = summary([makeSample(at: 3000, temperature: 50, maxTemperature: 71)])
        let date = Date(timeIntervalSinceReferenceDate: 3000)
        #expect(
            ChartDetails.temperature(summary, hoverDate: date, preferences: preferences)
                == "\(date.formatted(TimeRange.quarter.hoverDateFormat))  \(preferences.format(71, decimals: 1))")
    }

    @Test func longRangesShowTheWeekday() {
        #expect(TimeRange.day.hoverDateFormat == .dateTime.weekday(.abbreviated).hour().minute())
        #expect(TimeRange.hour.hoverDateFormat == .dateTime.hour().minute().second())
        #expect(TimeRange.week.axisDateFormat == .dateTime.weekday(.abbreviated))
        #expect(TimeRange.quarter.axisDateFormat == .dateTime.hour().minute())
    }
}
