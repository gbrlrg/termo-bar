import Foundation
import Testing

struct WidgetContentTests {
    private let end = Date(timeIntervalSinceReferenceDate: 3600)

    /// Dois registros de 10 s com a mesma potência por app.
    private func summary(_ power: [String: Power], openApps: [String] = []) -> RangeSummary {
        let history = [3580.0, 3590].map {
            makeSample(at: $0, duration: 10, openApps: openApps, appPower: power)
        }
        return RangeSummary(range: .quarter, history: history, end: end, highlighted: []) { $0.uppercased() }
    }

    @Test func heatingAppsSkipOthersAndAppsWithoutEnergy() {
        let result = summary(
            [
                "a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 3, gpu: 0),
                AppID.others: Power(cpu: 5, gpu: 0),
            ],
            openApps: ["idle"])

        #expect(result.rows.contains { $0.id == "idle" })
        #expect(result.heatingApps.map(\.id) == ["b", "a"])
    }

    @Test func heatingAppsAreEmptyWithoutMeasurements() {
        let history = [makeSample(at: 3590, openApps: ["a"])]
        let result = RangeSummary(range: .quarter, history: history, end: end, highlighted: []) { $0 }

        #expect(result.heatingApps.isEmpty)
    }

    @Test func snapshotListsTopAppsWithTheirChartColors() throws {
        var palette = PaletteSlots(capacity: 2)
        palette.update(ranking: ["c", "b"])
        let result = summary([
            "a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 2, gpu: 0.5),
            "c": Power(cpu: 4, gpu: 0), "d": Power(cpu: 0.5, gpu: 0),
        ])

        let snapshot = WidgetSnapshot(
            date: end, celsius: 61.4, temperature: "61 °C", pressure: .moderate,
            summary: result, palette: palette, limit: 3)

        #expect(snapshot.apps.map(\.id) == ["c", "b", "a"])
        #expect(snapshot.apps.map(\.name) == ["C", "B", "A"])
        #expect(snapshot.apps.map(\.colorSlot) == [0, 1, nil])
        #expect(snapshot.apps.map(\.watts) == [4.0, 2.5, 1.0].map { $0.formatted(.watts) })
        let top = try #require(snapshot.apps.first)
        #expect(abs(top.share - 4 / 8) < 1e-9)
        #expect(snapshot.temperature == "61 °C")
        #expect(snapshot.pressure == .moderate)
        #expect(snapshot.date == end)
    }

    @Test func snapshotWithoutEnergyHasNoApps() {
        let snapshot = WidgetSnapshot(
            date: end, celsius: 50, temperature: "50 °C", pressure: .nominal,
            summary: summary([:], openApps: ["a"]), palette: PaletteSlots(capacity: 2), limit: 3)

        #expect(snapshot.apps.isEmpty)
    }

    @Test func unsavedNamesAreNewOrRenamedOnly() {
        let saved = ["a": "Alpha", "b": "Beta"]
        let names = ["a": "Alpha", "b": "Beta 2", "c": "Gamma"]

        #expect(AppID.unsavedNames(names, saved: saved) == ["b": "Beta 2", "c": "Gamma"])
        #expect(AppID.unsavedNames(saved, saved: saved).isEmpty)
    }
}
