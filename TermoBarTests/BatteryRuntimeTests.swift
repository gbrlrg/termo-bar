import Foundation
import Testing

struct BatteryRuntimeTests {
    private func battery(
        watts: Double?, pluggedIn: Bool = false, remainingMilliampHours: Double = 5000
    ) -> BatteryStatus? {
        var properties: [String: Any] = [
            "CurrentCapacity": 50, "MaxCapacity": 100, "ExternalConnected": pluggedIn,
            "Voltage": 10000,
            "Amperage": watts.map { UInt64(bitPattern: Int64(-($0 / 10 * 1000))) } ?? 0,
            "BatteryData": ["FullChargeCapacity": 10000, "RemainingCapacity": remainingMilliampHours],
        ]
        properties["IsCharging"] = false
        return BatteryStatus(properties: properties)
    }

    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSinceReferenceDate: seconds) }

    /// Registra uma leitura a cada 5 s, no consumo dado.
    private func record(
        _ history: inout DischargeHistory, watts: Double, from start: TimeInterval, to end: TimeInterval
    ) {
        for second in stride(from: start, through: end, by: 5) {
            history.record(battery(watts: watts), at: date(second))
        }
    }

    @Test func estimatesRemainingEnergyOverAveragePower() throws {
        var history = DischargeHistory()
        record(&history, watts: 10, from: 0, to: 300)
        // 5 Ah a 10 V = 50 Wh; a 10 W duram 5 h.
        let estimate = try #require(history.estimate(for: battery(watts: 10)))
        #expect(abs(estimate.hours - 5) < 0.001)
        #expect(abs(estimate.watts - 10) < 0.001)
        #expect(estimate.basis == 300)
    }

    @Test func waitsForEnoughMeasurement() {
        var history = DischargeHistory()
        record(&history, watts: 10, from: 0, to: DischargeHistory.minimumCoverage - 5)
        #expect(history.estimate(for: battery(watts: 10)) == nil)
        record(&history, watts: 10, from: DischargeHistory.minimumCoverage, to: DischargeHistory.minimumCoverage)
        #expect(history.estimate(for: battery(watts: 10)) != nil)
    }

    @Test func averagesOnlyTheRecentWindow() throws {
        var history = DischargeHistory()
        record(&history, watts: 40, from: 0, to: 300)
        record(&history, watts: 10, from: 305, to: 305 + DischargeHistory.window + 5)
        let estimate = try #require(history.estimate(for: battery(watts: 10)))
        #expect(abs(estimate.watts - 10) < 0.5)
    }

    @Test func pluggingInDiscardsTheHistory() {
        var history = DischargeHistory()
        record(&history, watts: 10, from: 0, to: 300)
        history.record(battery(watts: nil, pluggedIn: true), at: date(305))
        record(&history, watts: 10, from: 310, to: 330)
        #expect(history.estimate(for: battery(watts: 10)) == nil)
    }

    @Test func aLongGapLikeSleepDiscardsTheHistory() {
        var history = DischargeHistory()
        record(&history, watts: 10, from: 0, to: 300)
        record(&history, watts: 10, from: 300 + DischargeHistory.maximumGap + 10, to: 400 + DischargeHistory.maximumGap)
        #expect(history.estimate(for: battery(watts: 10)) == nil)
    }

    @Test func noEstimateWhilePluggedInOrWithoutBattery() {
        var history = DischargeHistory()
        record(&history, watts: 10, from: 0, to: 300)
        #expect(history.estimate(for: battery(watts: 10, pluggedIn: true)) == nil)
        #expect(history.estimate(for: nil) == nil)
    }

    @Test func noEstimateFromNoisePower() {
        var history = DischargeHistory()
        record(&history, watts: 0.1, from: 0, to: 300)
        #expect(history.estimate(for: battery(watts: 0.1)) == nil)
    }

    @Test func noEstimateWithoutKnownCapacity() {
        var history = DischargeHistory()
        record(&history, watts: 10, from: 0, to: 300)
        let noCapacity = BatteryStatus(properties: [
            "CurrentCapacity": 50, "MaxCapacity": 100, "Voltage": 10000, "Amperage": UInt64(bitPattern: -1000),
        ])
        #expect(history.estimate(for: noCapacity) == nil)
    }

    @Test func roundsMinutesToWhatTheMeasurementSupports() {
        func rounded(hours: Double) -> Int { RuntimeEstimate(hours: hours, watts: 5, basis: 300).roundedMinutes }
        #expect(rounded(hours: 0.52) == 30)  // 31,2 min
        #expect(rounded(hours: 3.4) == 200)  // 204 min
        #expect(rounded(hours: 3.45) == 210)  // 207 min
    }

    @Test func flagsEstimatesBeyondADay() {
        #expect(RuntimeEstimate(hours: 25, watts: 1, basis: 300).exceedsDisplayLimit)
        #expect(!RuntimeEstimate(hours: 23, watts: 1, basis: 300).exceedsDisplayLimit)
    }
}
