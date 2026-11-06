import Foundation
import Testing

/// Casos de borda dos alertas, da bateria, das amostras e do resumo por período.
struct DomainEdgeCaseTests {
    // MARK: - Alertas

    @Test func emptyHistoryNeverWarns() {
        var policy = AlertPolicy()
        let configuration = AlertConfiguration(temperatureLimit: 50, throttling: true, appPower: nil)
        #expect(policy.evaluate([], configuration: configuration, source: .average).isEmpty)
    }

    @Test func aGapLikeSleepRestartsTheSustainedTimer() {
        var policy = AlertPolicy()
        let configuration = AlertConfiguration(temperatureLimit: 90, throttling: false, appPower: nil)
        var history = [makeSample(at: 0, temperature: 95)]
        #expect(policy.evaluate(history, configuration: configuration, source: .average).isEmpty)
        // Acordou uma hora depois ainda quente: só avisa depois de 30 s seguidos de novo.
        history.append(makeSample(at: 3600, temperature: 95))
        #expect(policy.evaluate(history, configuration: configuration, source: .average).isEmpty)
        history.append(makeSample(at: 3630, temperature: 95))
        // 30 s depois, mas com um buraco de 30 s entre as leituras de 5 s: ainda não é contínuo.
        #expect(policy.evaluate(history, configuration: configuration, source: .average).isEmpty)
        for second in stride(from: 3635.0, through: 3665, by: 5) {
            history.append(makeSample(at: second, temperature: 95))
        }
        #expect(policy.evaluate(history, configuration: configuration, source: .average).count == 1)
    }

    @Test func eventsHaveKeysAndCooldowns() {
        let consumer = PowerConsumer(app: "a", watts: 1)
        #expect(AlertEvent.highTemperature(celsius: 1, limit: 1, topConsumer: nil).key == "temp")
        #expect(AlertEvent.throttling(nil, topConsumer: nil).key == "throttle")
        #expect(AlertEvent.appPower(consumer, window: 60).key == "app:a")
        #expect(AlertEvent.throttling(nil, topConsumer: nil).cooldown == AlertPolicy.cooldown)
        #expect(AlertEvent.appPower(consumer, window: 60).cooldown == AlertPolicy.appCooldown)
    }

    @Test func heavyConsumersAreSortedAndEachHasItsOwnCooldown() {
        let limit = AlertConfiguration.AppPowerLimit(watts: 5, window: 60)
        let configuration = AlertConfiguration(temperatureLimit: nil, throttling: false, appPower: limit)
        let power = ["b": Power(cpu: 6, gpu: 0), "a": Power(cpu: 9, gpu: 0)]
        var policy = AlertPolicy()
        var history = (0..<7).map { makeSample(at: Double($0) * 10, duration: 10, appPower: power) }

        #expect(
            policy.evaluate(history, configuration: configuration, source: .average) == [
                .appPower(PowerConsumer(app: "a", watts: 9), window: 60),
                .appPower(PowerConsumer(app: "b", watts: 6), window: 60),
            ])
        history.append(makeSample(at: 70, duration: 10, appPower: power))
        #expect(policy.evaluate(history, configuration: configuration, source: .average).isEmpty)
    }

    @Test func highTemperatureWithoutMeasuredPowerHasNoConsumer() {
        var policy = AlertPolicy()
        let configuration = AlertConfiguration(temperatureLimit: 90, throttling: false, appPower: nil)
        var history: [Sample] = []
        var sent: [AlertEvent] = []
        for second in stride(from: 0.0, through: 30, by: 5) {
            history.append(makeSample(at: second, temperature: 95))
            sent += policy.evaluate(history, configuration: configuration, source: .hottest)
        }
        #expect(sent == [.highTemperature(celsius: 95, limit: 90, topConsumer: nil)])
    }

    // MARK: - Bateria

    @Test func batteryWithoutVoltageOrCurrentHasNoEnergyNorDischarge() throws {
        let status = try #require(
            BatteryStatus(properties: [
                "CurrentCapacity": 50, "MaxCapacity": 100, "DesignCycleCount9C": 0,
                "BatteryData": ["FullChargeCapacity": 5000, "RemainingCapacity": 2500],
            ]))
        #expect(status.voltage == 0)
        #expect(status.fullEnergy == nil)
        #expect(status.remainingEnergy == nil)
        #expect(status.dischargeWatts == nil)
        #expect(status.designCycleCount == nil)
        #expect(status.cycleCount == nil)
        #expect(!status.isDischarging)
        #expect(!status.isPluggedIn && !status.isCharging)
    }

    @Test func drainNeedsAKnownCapacityAndNonNegativePower() {
        #expect(BatteryDrain.percentPerHour(watts: 6, fullEnergy: nil) == nil)
        #expect(BatteryDrain.percentPerHour(watts: 6, fullEnergy: 0) == nil)
        #expect(BatteryDrain.percentPerHour(watts: -1, fullEnergy: 60) == nil)
        #expect(BatteryDrain.notablePercentPerHour(watts: 6, fullEnergy: nil) == nil)
    }

    // MARK: - Amostras e período

    @Test func fanSpinningNeedsAReading() {
        #expect(!makeSample(at: 0, fanSpeed: nil).isFanSpinning)
        #expect(!makeSample(at: 0, fanSpeed: 99).isFanSpinning)
        #expect(makeSample(at: 0, fanSpeed: 100).isFanSpinning)
        #expect([Sample]().peakFanSpeed == nil)
        #expect([Sample]().fanSpinningShare == nil)
        #expect([Sample]().throttledShare == nil)
        #expect([Sample]().averageTemperature(for: .average) == nil)
        #expect([Sample]().nearest(to: .now) == nil)
    }

    @Test func minuteSummaryWithoutDurationIsNil() {
        #expect(Sample(summarizing: [makeSample(at: 0, duration: 0)], at: .now) == nil)
    }

    @Test func summaryReportsFanDataAndBinSize() {
        let end = Date(timeIntervalSinceReferenceDate: 3600)
        let withFan = RangeSummary(
            range: .hour, history: [makeSample(at: 3000, fanSpeed: 1500)], end: end, highlighted: []
        ) { $0 }
        #expect(withFan.hasFanData)
        #expect(withFan.binSize == 60)
        #expect(
            withFan.bin(for: Date(timeIntervalSinceReferenceDate: 3001)) == Date(timeIntervalSinceReferenceDate: 3000))
        #expect(withFan.averagePower == nil)
        let without = RangeSummary(range: .hour, history: [makeSample(at: 3000)], end: end, highlighted: []) { $0 }
        #expect(!without.hasFanData)
    }

    @Test func slicesHaveStableIDsAndWatts() {
        let slice = PowerSlice(start: Date(timeIntervalSinceReferenceDate: 30), app: "a", low: 1, high: 3.5)
        #expect(slice.id == "30.0-a")
        #expect(slice.watts == 2.5)
    }

    @Test func appsWithTheSameEnergyAreSortedByName() {
        let end = Date(timeIntervalSinceReferenceDate: 3600)
        let summary = RangeSummary(
            range: .quarter, history: [makeSample(at: 3000, openApps: ["b", "a", "c"], appPower: [:])], end: end,
            highlighted: []
        ) { ["a": "Zeta", "b": "Alfa", "c": "Beta"][$0] ?? $0 }
        #expect(summary.rows.map(\.name) == ["Alfa", "Beta", "Zeta"])
        #expect(summary.rows.allSatisfy { $0.share == 0 && $0.average == .zero })
    }

    @Test func heatOfShortReadingsIsNotInflated() {
        let end = Date(timeIntervalSinceReferenceDate: 3600)
        // Uma leitura de meio segundo: a potência média da faixa não passa a potência medida.
        let summary = RangeSummary(
            range: .quarter, history: [makeSample(at: 3000, duration: 0.5, appPower: ["a": Power(cpu: 4, gpu: 0)])],
            end: end, highlighted: ["a"]
        ) { $0 }
        #expect((summary.rows.first?.heat.values.max() ?? 0) <= 4)
    }
}
