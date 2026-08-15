import Foundation
import Testing

struct HistoryStoreTests {
    @Test func roundTripsSamples() throws {
        let store = try HistoryStore.inMemory()
        let measured = makeSample(
            at: 100, duration: 5, temperature: 55, maxTemperature: 70, openApps: ["a", "b"], frontmostApp: "a",
            appPower: ["a": Power(cpu: 1.5, gpu: 0.25)], pressure: 2, gpuPower: 0.25)
        let unmeasured = makeSample(at: 105, appPower: nil, pressure: nil)

        try store.insert(unmeasured, resolution: .raw)
        try store.insert(measured, resolution: .raw)
        try store.insert(makeSample(at: 100), resolution: .minute)

        let loaded = try store.samples(resolution: .raw, since: .distantPast)
        #expect(loaded.count == 2)
        let first = try #require(loaded.first)
        #expect(first.date == measured.date)
        #expect(first.averageTemperature == 55)
        #expect(first.maxTemperature == 70)
        #expect(first.openApps == ["a", "b"])
        #expect(first.frontmostApp == "a")
        #expect(first.appPower == ["a": Power(cpu: 1.5, gpu: 0.25)])
        #expect(first.pressure == 2)
        #expect(first.gpuPower == 0.25)
        #expect(loaded[1].appPower == nil)
        #expect(loaded[1].pressure == nil)
        #expect(loaded[1].gpuPower == nil)
    }

    @Test func prunesOldSamplesOfOneResolution() throws {
        let store = try HistoryStore.inMemory()
        for seconds in [0.0, 10, 20] {
            try store.insert(makeSample(at: seconds, appPower: ["a": Power(cpu: 1, gpu: 0)]), resolution: .raw)
        }
        try store.insert(makeSample(at: 0), resolution: .minute)

        try store.prune(resolution: .raw, before: Date(timeIntervalSinceReferenceDate: 10))

        #expect(
            try store.samples(resolution: .raw, since: .distantPast).map(\.date.timeIntervalSinceReferenceDate) == [
                10, 20,
            ])
        #expect(try store.samples(resolution: .minute, since: .distantPast).count == 1)
    }

    @Test func storesNamesAndDeletesEverything() throws {
        let store = try HistoryStore.inMemory()
        try store.saveNames(["a": "App A", "b": "App B"])
        try store.saveNames(["a": "App A2"])
        try store.insert(makeSample(at: 0), resolution: .raw)
        #expect(try store.names() == ["a": "App A2", "b": "App B"])

        try store.deleteAll()

        #expect(try store.names().isEmpty)
        #expect(try store.samples(resolution: .raw, since: .distantPast).isEmpty)
    }

    @Test func treatsHostileTextAsData() throws {
        let store = try HistoryStore.inMemory()
        let name = "x'); DROP TABLE samples; --"
        try store.saveNames([name: name])
        try store.insert(makeSample(at: 0, openApps: [name], frontmostApp: name), resolution: .raw)
        #expect(try store.names() == [name: name])
        #expect(try store.samples(resolution: .raw, since: .distantPast).first?.frontmostApp == name)
    }

    @Test func exportsCSVFile() throws {
        let store = try HistoryStore.inMemory()
        try store.insert(makeSample(at: 0, appPower: ["a": Power(cpu: 1, gpu: 0)]), resolution: .raw)
        let url = FileManager.default.temporaryDirectory.appending(path: "termobar-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: url) }

        try store.exportCSV(resolution: .raw, to: url)

        let csv = try String(contentsOf: url, encoding: .utf8)
        #expect(csv.split(separator: "\n").count == 2)
    }
}
