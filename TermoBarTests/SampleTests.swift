import Foundation
import Testing

struct SampleTests {
    @Test func energyAndAveragePowerAreWeightedByDuration() throws {
        let samples = [
            makeSample(at: 0, duration: 10, appPower: ["a": Power(cpu: 2, gpu: 1)]),
            makeSample(at: 10, duration: 30, appPower: ["a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 4, gpu: 0)]),
            makeSample(at: 40, duration: 60, appPower: nil),
        ]

        #expect(samples.totalDuration == 100)
        #expect(samples.measuredDuration == 40)
        #expect(samples.energyByApp() == ["a": Power(cpu: 50, gpu: 10), "b": Power(cpu: 120, gpu: 0)])

        let average = try #require(samples.averagePowerByApp())
        #expect(average["a"] == Power(cpu: 1.25, gpu: 0.25))
        #expect(average["b"] == Power(cpu: 3, gpu: 0))
    }

    @Test func averagePowerIsNilWithoutMeasurements() {
        #expect([makeSample(at: 0)].averagePowerByApp() == nil)
    }

    @Test func minuteSummaryCombinesSamples() throws {
        let samples = [
            makeSample(
                at: 0, duration: 20, temperature: 40, maxTemperature: 70, openApps: ["b", "a"],
                frontmostApp: "a", appPower: ["a": Power(cpu: 3, gpu: 0)], pressure: 1, gpuPower: 1),
            makeSample(
                at: 20, duration: 40, temperature: 70, maxTemperature: 80, openApps: ["a", "c"],
                frontmostApp: "c", appPower: ["a": Power(cpu: 0, gpu: 0.003)], pressure: 2, gpuPower: 3),
            makeSample(at: 40, duration: 0, frontmostApp: "c", pressure: nil),
        ]
        let date = Date(timeIntervalSinceReferenceDate: 0)

        let summary = try #require(Sample(summarizing: samples, at: date))

        #expect(summary.date == date)
        #expect(summary.duration == Sample.minuteDuration)
        #expect(summary.averageTemperature == 60)
        #expect(summary.maxTemperature == 80)
        #expect(summary.openApps == ["a", "b", "c"])
        #expect(summary.frontmostApp == "c")
        #expect(summary.pressure == 2)
        #expect(summary.gpuPower == 2)
        #expect(summary.appPower?["a"]?.cpu == 1)
    }

    @Test func minuteSummaryDropsInsignificantPower() throws {
        let samples = [makeSample(at: 0, appPower: ["idle": Power(cpu: 0.001, gpu: 0.001)])]
        let summary = try #require(Sample(summarizing: samples, at: .now))
        #expect(summary.appPower == [:])
    }

    @Test func minuteSummaryBreaksFrontmostTiesDeterministically() throws {
        let samples = [makeSample(at: 0, frontmostApp: "b"), makeSample(at: 5, frontmostApp: "a")]
        #expect(try #require(Sample(summarizing: samples, at: .now)).frontmostApp == "a")
    }

    @Test func minuteSummaryOfNothingIsNil() {
        #expect(Sample(summarizing: [], at: .now) == nil)
    }

    @Test func intervalsSplitOnPredicateAndGaps() {
        let samples = [
            makeSample(at: 0, openApps: ["a"]),
            makeSample(at: 5, openApps: ["a"]),
            makeSample(at: 10, openApps: []),
            makeSample(at: 15, openApps: ["a"]),
            // Buraco de 60 s (> 3 × 5 s): Mac dormindo.
            makeSample(at: 75, openApps: ["a"]),
        ]

        let intervals = samples.intervals { $0.openApps.contains("a") }

        #expect(
            intervals.map { [$0.lowerBound, $0.upperBound].map(\.timeIntervalSinceReferenceDate) } == [
                [0, 10], [15, 20], [75, 80],
            ])
    }

    @Test func nearestSample() {
        let samples = [makeSample(at: 0), makeSample(at: 10), makeSample(at: 20)]
        #expect(
            samples.nearest(to: Date(timeIntervalSinceReferenceDate: 12))?.date.timeIntervalSinceReferenceDate == 10)
        #expect([Sample]().nearest(to: .now) == nil)
    }

    @Test func throttlingStartsAtHeavyPressure() {
        #expect(!makeSample(at: 0, pressure: nil).isThrottling)
        #expect(!makeSample(at: 0, pressure: ThermalPressure.moderate.rawValue).isThrottling)
        #expect(makeSample(at: 0, pressure: ThermalPressure.heavy.rawValue).isThrottling)
        #expect(ThermalPressure.critical.isThrottling)
        #expect(!ThermalPressure.nominal.isThrottling)
    }

    @Test func temperatureSource() {
        let sample = makeSample(at: 0, temperature: 50, maxTemperature: 70)
        #expect(sample.temperature(for: .average) == 50)
        #expect(sample.temperature(for: .hottest) == 70)
        #expect([sample].averageTemperature(for: .hottest) == 70)
    }
}
