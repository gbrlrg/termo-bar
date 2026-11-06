import Foundation
import Testing

struct RangeSummaryCacheTests {
    private let end = Date(timeIntervalSinceReferenceDate: 3600)
    private let history = [
        makeSample(at: 3000, openApps: ["a"], appPower: ["a": Power(cpu: 1, gpu: 0)]),
        makeSample(at: 3005, openApps: ["a"], appPower: ["a": Power(cpu: 3, gpu: 0)]),
    ]

    @Test func matchesAFreshSummary() {
        var cache = RangeSummaryCache()
        let cached = cache.summary(range: .quarter, history: history, end: end, highlighted: ["a"], names: ["a": "App"])
        let fresh = RangeSummary(range: .quarter, history: history, end: end, highlighted: ["a"]) {
            AppID.displayName(of: $0, names: ["a": "App"])
        }
        #expect(cached.rows.map(\.name) == fresh.rows.map(\.name))
        #expect(cached.rows.map(\.energy) == fresh.rows.map(\.energy))
        #expect(cached.stacked == fresh.stacked)
        #expect(cached.slices.map(\.id) == fresh.slices.map(\.id))
    }

    @Test func reusesTheSummaryWhileNothingChanges() {
        var cache = RangeSummaryCache()
        _ = cache.summary(range: .quarter, history: history, end: end, highlighted: [], names: [:])
        // Mesmo tamanho, mesmo início e mesmo fim: o histórico só cresce no fim e encolhe no começo,
        // então é o mesmo e o resumo guardado vale (a potência diferente no meio não é relida).
        var same = history
        same[1] = makeSample(at: 3005, openApps: ["a"], appPower: ["a": Power(cpu: 99, gpu: 0)])
        let reused = cache.summary(range: .quarter, history: same, end: end, highlighted: [], names: [:])
        #expect(reused.rows.first?.energy == Power(cpu: 20, gpu: 0))
    }

    @Test func rebuildsWhenAnyInputChanges() {
        var cache = RangeSummaryCache()
        _ = cache.summary(range: .quarter, history: history, end: end, highlighted: [], names: [:])

        let renamed = cache.summary(range: .quarter, history: history, end: end, highlighted: [], names: ["a": "novo"])
        #expect(renamed.rows.first?.name == "novo")
        let highlighted = cache.summary(
            range: .quarter, history: history, end: end, highlighted: ["a"], names: ["a": "novo"])
        #expect(highlighted.stacked == ["a"])
        let longer = history + [makeSample(at: 3010, openApps: ["b"])]
        let grown = cache.summary(range: .quarter, history: longer, end: end, highlighted: ["a"], names: ["a": "novo"])
        #expect(grown.rows.count == 2)
        let later = cache.summary(
            range: .quarter, history: longer, end: end.addingTimeInterval(900), highlighted: ["a"],
            names: ["a": "novo"])
        #expect(later.samples.isEmpty)
    }

    @Test func keepsOneSummaryPerRange() {
        var cache = RangeSummaryCache()
        let quarter = cache.summary(range: .quarter, history: history, end: end, highlighted: [], names: [:])
        let hour = cache.summary(range: .hour, history: history, end: end, highlighted: [], names: [:])
        #expect(quarter.range == .quarter)
        #expect(hour.range == .hour)
        #expect(
            cache.summary(range: .quarter, history: history, end: end, highlighted: [], names: [:]).range == .quarter)
    }

    @Test func displayNameUsesKnownNamesAndOthers() {
        #expect(AppID.displayName(of: "a", names: ["a": "App"]) == "App")
        #expect(AppID.displayName(of: "b", names: ["a": "App"]) == "b")
        #expect(AppID.displayName(of: AppID.others, names: [AppID.others: "x"]) == AppID.othersName)
    }
}
