import Foundation
import Testing

struct WidgetSnapshotTests {
    private func snapshot(
        at seconds: TimeInterval = 0, celsius: Double = 60, temperature: String = "60 °C",
        pressure: ThermalPressure = .nominal, top: String? = "a"
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            date: Date(timeIntervalSinceReferenceDate: seconds), celsius: celsius, temperature: temperature,
            pressure: pressure,
            apps: top.map { [WidgetSnapshot.App(id: $0, name: "App", watts: "1 W", share: 0.5, colorSlot: 0)] } ?? [])
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "termobar-\(UUID().uuidString)/widget.json")
    }

    @Test func roundTripsThroughTheSharedFile() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let saved = snapshot(pressure: .heavy)

        try saved.save(to: url)

        #expect(WidgetSnapshot.load(from: url) == saved)
    }

    @Test func missingOrCorruptFileLoadsNothing() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(WidgetSnapshot.load(from: url) == nil)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"date\": 1}".utf8).write(to: url)
        #expect(WidgetSnapshot.load(from: url) == nil)
    }

    @Test func becomesStaleAfterFifteenMinutes() {
        let fresh = snapshot(at: 0)
        #expect(!fresh.isStale(at: Date(timeIntervalSinceReferenceDate: WidgetSnapshot.staleInterval)))
        #expect(fresh.isStale(at: Date(timeIntervalSinceReferenceDate: WidgetSnapshot.staleInterval + 1)))
        #expect(!WidgetSnapshot.placeholder.isStale)
        #expect(snapshot(at: 0).isStale)
    }

    @Test func reloadsAtMostOncePerMinute() {
        let last = snapshot(at: 0)
        #expect(!snapshot(at: 59, celsius: 90).needsReload(since: last))
        #expect(snapshot(at: 60, celsius: 90).needsReload(since: last))
    }

    @Test func reloadsOnlyForVisibleChanges() {
        let last = snapshot(at: 0)
        #expect(!snapshot(at: 120, celsius: 60.9).needsReload(since: last))
        #expect(snapshot(at: 120, celsius: 61).needsReload(since: last))
        #expect(snapshot(at: 120, temperature: "60,0 °C").needsReload(since: last))
        #expect(snapshot(at: 120, temperature: "60 °F").needsReload(since: last))
        #expect(snapshot(at: 120, pressure: .moderate).needsReload(since: last))
        #expect(snapshot(at: 120, top: "b").needsReload(since: last))
        #expect(snapshot(at: 120, top: nil).needsReload(since: last))
    }

    @Test func placeholderShowsSampleApps() {
        #expect(WidgetSnapshot.placeholder.apps.count == 3)
        #expect(WidgetSnapshot.placeholder.apps.map(\.colorSlot) == [0, 1, 2])
        #expect(WidgetSnapshot.timelineRefresh > 0)
    }
}
