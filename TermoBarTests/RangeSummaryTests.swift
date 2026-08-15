import Foundation
import Testing

struct RangeSummaryTests {
    private let end = Date(timeIntervalSinceReferenceDate: 3600)

    private func summary(_ history: [Sample], highlighted: Set<String> = []) -> RangeSummary {
        RangeSummary(range: .quarter, history: history, end: end, highlighted: highlighted) { $0.uppercased() }
    }

    @Test func keepsOnlySamplesInRange() {
        let result = summary([makeSample(at: 0), makeSample(at: 3000), makeSample(at: 3600)])
        #expect(result.start == end.addingTimeInterval(-900))
        #expect(result.samples.map(\.date.timeIntervalSinceReferenceDate) == [3000, 3600])
        #expect(!result.hasEnoughData)
    }

    @Test func ranksAppsByEnergy() throws {
        let history = [
            makeSample(
                at: 3000, duration: 10, openApps: ["a", "idle"],
                appPower: ["a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 3, gpu: 0)]),
            makeSample(
                at: 3010, duration: 10, openApps: ["a", "idle"],
                appPower: ["a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 3, gpu: 0)]),
        ]

        let result = summary(history)

        #expect(result.rows.map(\.id) == ["b", "a", "idle"])
        #expect(result.rows.map(\.name) == ["B", "A", "IDLE"])
        let b = try #require(result.rows.first)
        #expect(b.energy == Power(cpu: 60, gpu: 0))
        #expect(b.share == 0.75)
        #expect(b.average == Power(cpu: 3, gpu: 0))
        #expect(result.measured == 20)
        #expect(result.averagePower == 4)
    }

    @Test func hidesInsignificantLooseProcesses() {
        let history = [
            makeSample(at: 3000, appPower: ["app": Power(cpu: 10, gpu: 0), "proc:tiny": Power(cpu: 0.05, gpu: 0)])
        ]
        #expect(summary(history).rows.map(\.id) == ["app"])
    }

    @Test func stacksHighlightedAppsBelowOthers() throws {
        // Ambas as amostras caem na mesma faixa de 15 s.
        let history = [
            makeSample(
                at: 3000, duration: 5,
                appPower: ["a": Power(cpu: 2, gpu: 0), "b": Power(cpu: 1, gpu: 0), "c": Power(cpu: 1, gpu: 0)]),
            makeSample(at: 3005, duration: 5, appPower: ["a": Power(cpu: 4, gpu: 0)]),
        ]

        let result = summary(history, highlighted: ["a", "z"])

        #expect(result.stacked == ["a"])
        let bin = result.bin(for: Date(timeIntervalSinceReferenceDate: 3000))
        #expect(result.slices.map(\.app) == ["a", AppID.others])
        #expect(result.slices.map(\.low) == [0, 3])
        #expect(result.slices.map(\.high) == [3, 4])
        #expect(result.binTotals == [bin: 4])
        #expect(result.peakHeat == 3)
    }

    @Test func peakHeatHasAFloor() {
        let history = [makeSample(at: 3000, appPower: ["a": Power(cpu: 0.1, gpu: 0)])]
        #expect(summary(history).peakHeat == RangeSummary.minimumPeakHeat)
    }

    @Test func marksThrottledIntervals() {
        let history = [
            makeSample(at: 3000, pressure: 0),
            makeSample(at: 3005, pressure: 2),
            makeSample(at: 3010, pressure: 3),
            makeSample(at: 3015, pressure: 1),
        ]
        let throttled = summary(history).throttled
        #expect(throttled.map(\.lowerBound.timeIntervalSinceReferenceDate) == [3005])
        #expect(throttled.map(\.upperBound.timeIntervalSinceReferenceDate) == [3015])
    }

    @Test func binsAlignToRangeSize() {
        #expect(
            TimeRange.hour.bin(containing: Date(timeIntervalSinceReferenceDate: 119))
                == Date(timeIntervalSinceReferenceDate: 60))
        #expect(
            TimeRange.week.bin(containing: Date(timeIntervalSinceReferenceDate: 7199))
                == Date(timeIntervalSinceReferenceDate: 3600))
        #expect(TimeRange.day.usesMinuteSummaries)
        #expect(!TimeRange.hour.usesMinuteSummaries)
    }
}
