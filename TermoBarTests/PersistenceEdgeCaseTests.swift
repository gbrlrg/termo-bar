import Foundation
import Testing

/// Erros do SQLite e casos de borda do histórico e da exportação.
struct PersistenceEdgeCaseTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "termobar-\(UUID().uuidString)")
    }

    @Test func openingAnImpossiblePathThrows() {
        #expect(throws: SQLiteError.self) {
            try SQLiteDatabase(path: "/nao/existe/\(UUID().uuidString)/history.sqlite")
        }
    }

    @Test func invalidSQLThrowsWithTheMessage() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        do {
            try database.execute("SELEC 1")
            Issue.record("SQL inválido foi aceito")
        } catch let error as SQLiteError {
            #expect(error.description == "SQLite \(error.code): \(error.message)")
            #expect(error.code != 0)
            #expect(!error.message.isEmpty)
        }
        #expect(throws: SQLiteError.self) { try database.prepare("SELECT * FROM tabela_que_nao_existe") }
        #expect(throws: SQLiteError.self) { try database.run("SELECT ?", [.integer(1), .integer(2)]) }
    }

    @Test func failedStepThrows() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t(id INTEGER PRIMARY KEY)")
        try database.run("INSERT INTO t VALUES(?)", [.integer(1)])
        #expect(throws: SQLiteError.self) { try database.run("INSERT INTO t VALUES(?)", [.integer(1)]) }
    }

    @Test func transactionRollsBackOnError() throws {
        struct Failure: Error {}
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t(v TEXT)")

        #expect(throws: Failure.self) {
            try database.transaction {
                try database.run("INSERT INTO t VALUES(?)", [.text("a")])
                throw Failure()
            }
        }

        var count = -1
        try database.query("SELECT COUNT(*) FROM t") { count = $0.integer(0) }
        #expect(count == 0)
    }

    @Test func bindsAndReadsEveryType() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t(i INTEGER, r REAL, s TEXT, n TEXT)")
        try database.run(
            "INSERT INTO t VALUES(?,?,?,?)", [.integer(Int?.some(7)), .real(Double?.some(1.5)), .text("é"), .null])
        try database.run("INSERT INTO t VALUES(?,?,?,?)", [.integer(nil), .real(nil), .text(nil), .null])

        var rows: [(Int?, Double?, String?, Bool)] = []
        try database.query("SELECT i, r, s, n FROM t ORDER BY rowid") { row in
            rows.append((row.optionalInteger(0), row.optionalDouble(1), row.text(2), row.isNull(3)))
        }
        #expect(rows.count == 2)
        #expect(rows[0].0 == 7 && rows[0].1 == 1.5 && rows[0].2 == "é" && rows[0].3)
        #expect(rows[1].0 == nil && rows[1].1 == nil && rows[1].2 == nil && rows[1].3)
    }

    @Test func preparedStatementsCanBeReused() throws {
        let database = try SQLiteDatabase(path: ":memory:")
        try database.execute("CREATE TABLE t(v INTEGER)")
        let insert = try database.prepare("INSERT INTO t VALUES(?)")
        for value in 1...3 { try insert.run([.integer(Int64(value))]) }
        var sum = 0
        try database.query("SELECT SUM(v) FROM t") { sum = $0.integer(0) }
        #expect(sum == 6)
    }

    // MARK: - Histórico

    @Test func replacingASampleReplacesItsPower() throws {
        let store = try HistoryStore.inMemory()
        try store.insert(
            makeSample(at: 0, appPower: ["a": Power(cpu: 1, gpu: 0), "b": Power(cpu: 2, gpu: 0)]), resolution: .minute)
        try store.insert(makeSample(at: 0, appPower: ["a": Power(cpu: 3, gpu: 0)]), resolution: .minute)

        let loaded = try store.samples(resolution: .minute, since: .distantPast)
        #expect(loaded.count == 1)
        #expect(loaded.first?.appPower == ["a": Power(cpu: 3, gpu: 0)])
    }

    @Test func measuredSampleWithoutAppsKeepsAnEmptyMeasurement() throws {
        let store = try HistoryStore.inMemory()
        try store.insert(makeSample(at: 0, appPower: [:]), resolution: .raw)
        #expect(try store.samples(resolution: .raw, since: .distantPast).first?.appPower == [:])
    }

    @Test func readsOnlySamplesSinceTheDate() throws {
        let store = try HistoryStore.inMemory()
        for seconds in [0.0, 10, 20] {
            try store.insert(makeSample(at: seconds, appPower: ["a": Power(cpu: seconds, gpu: 0)]), resolution: .raw)
        }
        let loaded = try store.samples(resolution: .raw, since: Date(timeIntervalSinceReferenceDate: 10))
        #expect(loaded.map(\.date.timeIntervalSinceReferenceDate) == [10, 20])
        #expect(loaded.first?.appPower == ["a": Power(cpu: 10, gpu: 0)])
    }

    @Test func toleratesRowsWrittenByHand() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "history.sqlite")
        _ = try HistoryStore(url: url)
        let database = try SQLiteDatabase(path: url.path(percentEncoded: false))
        try database.execute(
            """
            INSERT INTO samples VALUES(0, 0, 5, 50, 60, NULL, NULL, NULL, 'não é json', 1, NULL);
            INSERT INTO app_power VALUES(0, 0, 'a', 1, 0);
            INSERT INTO names VALUES('x', 'X');
            """)

        let store = try HistoryStore(url: url)
        let loaded = try store.samples(resolution: .raw, since: .distantPast)
        #expect(loaded.first?.openApps == [])
        #expect(loaded.first?.appPower == ["a": Power(cpu: 1, gpu: 0)])
        #expect(try store.names() == ["x": "X"])
    }

    @Test func historyInAnUnwritablePlaceThrows() {
        #expect(throws: (any Error).self) {
            try HistoryStore(url: URL(filePath: "/dev/null/termobar/history.sqlite"))
        }
    }

    @Test func exportToAMissingFolderThrows() throws {
        let store = try HistoryStore.inMemory()
        let url = temporaryDirectory().appending(path: "sub/history.csv")
        #expect(throws: (any Error).self) { try store.exportCSV(resolution: .raw, to: url) }
    }

    // MARK: - CSV

    @Test func quotesFieldsWithLineBreaksOfAnyKind() {
        #expect(CSVExporter.text("a\r\nb") == "\"a\r\nb\"")
        #expect(CSVExporter.text("a\nb") == "\"a\nb\"")
        #expect(CSVExporter.text("a\rb") == "\"a\rb\"")
        #expect(CSVExporter.text("simples") == "simples")
    }

    @Test func exportsInTheGivenTimeZone() {
        let csv = CSVExporter.csv(
            samples: [makeSample(at: 0)], names: [:], timeZone: TimeZone(secondsFromGMT: -3 * 3600) ?? .current)
        #expect(csv.split(separator: "\n").last?.hasPrefix("2000-12-31T21:00:00-03:00") == true)
    }
}
