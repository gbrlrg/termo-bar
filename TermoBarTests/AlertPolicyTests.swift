import Foundation
import Testing

struct AlertPolicyTests {
    private let temperatureOnly = AlertConfiguration(temperatureLimit: 90, throttling: false, appPower: nil)

    @Test func warnsOnlyAfterSustainedHighTemperature() {
        var policy = AlertPolicy()
        var history: [Sample] = []
        var sent: [AlertEvent] = []
        for second in stride(from: 0.0, through: 30, by: 5) {
            history.append(makeSample(at: second, temperature: 95, appPower: ["hot": Power(cpu: 20, gpu: 0)]))
            sent += policy.evaluate(history, configuration: temperatureOnly, source: .average)
        }
        #expect(
            sent == [
                .highTemperature(celsius: 95, limit: 90, topConsumer: PowerConsumer(app: "hot", watts: 20))
            ])
    }

    @Test func coolingDownResetsTheTimer() {
        var policy = AlertPolicy()
        let temperatures: [Double] = [95, 95, 95, 80, 95, 95, 95]
        var history: [Sample] = []
        var sent: [AlertEvent] = []
        for (index, temperature) in temperatures.enumerated() {
            history.append(makeSample(at: Double(index) * 10, temperature: temperature))
            sent += policy.evaluate(history, configuration: temperatureOnly, source: .average)
        }
        #expect(sent.isEmpty)
    }

    @Test func respectsCooldown() {
        var policy = AlertPolicy()
        let configuration = AlertConfiguration(temperatureLimit: 50, throttling: false, appPower: nil)
        var history: [Sample] = []
        var count = 0
        for second in stride(from: 0.0, through: AlertPolicy.cooldown + 60, by: 30) {
            history.append(makeSample(at: second, temperature: 60))
            count += policy.evaluate(history, configuration: configuration, source: .average).count
        }
        #expect(count == 2)
    }

    @Test func warnsWhenThrottlingStarts() {
        var policy = AlertPolicy()
        let configuration = AlertConfiguration(temperatureLimit: nil, throttling: true, appPower: nil)
        let history = [makeSample(at: 0, pressure: 0), makeSample(at: 5, pressure: 2)]

        #expect(policy.evaluate(Array(history.prefix(1)), configuration: configuration, source: .average).isEmpty)
        #expect(
            policy.evaluate(history, configuration: configuration, source: .average) == [
                .throttling(.heavy, topConsumer: nil)
            ])
    }

    @Test func warnsAboutAppsAboveTheLimitWithEnoughCoverage() {
        let limit = AlertConfiguration.AppPowerLimit(watts: 8, window: 60)
        let configuration = AlertConfiguration(temperatureLimit: nil, throttling: false, appPower: limit)
        let power = ["heavy": Power(cpu: 6, gpu: 4), "light": Power(cpu: 1, gpu: 0)]
        var policy = AlertPolicy()

        let partial = (0..<4).map { makeSample(at: Double($0) * 10, duration: 10, appPower: power) }
        #expect(policy.evaluate(partial, configuration: configuration, source: .average).isEmpty)

        let full = (0..<7).map { makeSample(at: Double($0) * 10, duration: 10, appPower: power) }
        #expect(
            policy.evaluate(full, configuration: configuration, source: .average) == [
                .appPower(PowerConsumer(app: "heavy", watts: 10), window: 60)
            ])
    }

    @Test func disabledConfigurationNeverWarns() {
        var policy = AlertPolicy()
        let configuration = AlertConfiguration(temperatureLimit: nil, throttling: false, appPower: nil)
        let history = (0..<100).map { makeSample(at: Double($0), temperature: 120, pressure: 4) }
        #expect(!configuration.isAnyEnabled)
        #expect(policy.evaluate(history, configuration: configuration, source: .hottest).isEmpty)
    }
}
