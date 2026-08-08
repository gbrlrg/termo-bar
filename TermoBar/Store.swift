import Foundation
import SQLite3

/// Histórico em SQLite: leituras finas (24 h) e resumos por minuto (até 30 dias).
final class Store {
    enum Resolution: Int32 {
        case raw = 0
        case minute = 1
    }

    private var db: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init() {
        let dir = URL.applicationSupportDirectory.appending(path: "TermoBar", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard sqlite3_open(dir.appending(path: "history.sqlite").path, &db) == SQLITE_OK else { db = nil; return }
        exec("""
            PRAGMA journal_mode=WAL;
            PRAGMA synchronous=NORMAL;
            CREATE TABLE IF NOT EXISTS samples(
                ts REAL NOT NULL, resolution INTEGER NOT NULL, duration REAL NOT NULL,
                temp REAL NOT NULL, max_temp REAL NOT NULL, pressure INTEGER, gpu REAL,
                front TEXT, apps TEXT NOT NULL, has_power INTEGER NOT NULL,
                PRIMARY KEY(resolution, ts));
            CREATE TABLE IF NOT EXISTS app_power(
                ts REAL NOT NULL, resolution INTEGER NOT NULL, app TEXT NOT NULL, cpu REAL NOT NULL, gpu REAL NOT NULL);
            CREATE INDEX IF NOT EXISTS app_power_ts ON app_power(resolution, ts);
            CREATE TABLE IF NOT EXISTS names(id TEXT PRIMARY KEY, name TEXT NOT NULL);
            """)
    }

    deinit { sqlite3_close(db) }

    // MARK: - Escrita

    func insert(_ sample: Sample, resolution: Resolution) {
        exec("BEGIN")
        let apps = (try? String(data: JSONEncoder().encode(sample.apps), encoding: .utf8)) ?? "[]"
        run("INSERT OR REPLACE INTO samples VALUES(?,?,?,?,?,?,?,?,?,?)") { s in
            sqlite3_bind_double(s, 1, sample.date.timeIntervalSince1970)
            sqlite3_bind_int(s, 2, resolution.rawValue)
            sqlite3_bind_double(s, 3, sample.duration)
            sqlite3_bind_double(s, 4, sample.temp)
            sqlite3_bind_double(s, 5, sample.maxTemp)
            bind(s, 6, sample.pressure)
            bind(s, 7, sample.gpu)
            bind(s, 8, sample.front)
            sqlite3_bind_text(s, 9, apps, -1, Self.transient)
            sqlite3_bind_int(s, 10, sample.power == nil ? 0 : 1)
        }
        for (app, power) in sample.power ?? [:] {
            run("INSERT INTO app_power VALUES(?,?,?,?,?)") { s in
                sqlite3_bind_double(s, 1, sample.date.timeIntervalSince1970)
                sqlite3_bind_int(s, 2, resolution.rawValue)
                sqlite3_bind_text(s, 3, app, -1, Self.transient)
                sqlite3_bind_double(s, 4, power.cpu)
                sqlite3_bind_double(s, 5, power.gpu)
            }
        }
        exec("COMMIT")
    }

    func saveNames(_ names: [String: String]) {
        exec("BEGIN")
        for (id, name) in names {
            run("INSERT OR REPLACE INTO names VALUES(?,?)") { s in
                sqlite3_bind_text(s, 1, id, -1, Self.transient)
                sqlite3_bind_text(s, 2, name, -1, Self.transient)
            }
        }
        exec("COMMIT")
    }

    func prune(resolution: Resolution, before date: Date) {
        for table in ["samples", "app_power"] {
            run("DELETE FROM \(table) WHERE resolution = ? AND ts < ?") { s in
                sqlite3_bind_int(s, 1, resolution.rawValue)
                sqlite3_bind_double(s, 2, date.timeIntervalSince1970)
            }
        }
    }

    func deleteAll() {
        exec("DELETE FROM samples; DELETE FROM app_power; DELETE FROM names;")
    }

    // MARK: - Leitura

    func load(resolution: Resolution, since date: Date) -> [Sample] {
        var power: [Double: [String: Power]] = [:]
        query("SELECT ts, app, cpu, gpu FROM app_power WHERE resolution = ? AND ts >= ?", bind: { s in
            sqlite3_bind_int(s, 1, resolution.rawValue)
            sqlite3_bind_double(s, 2, date.timeIntervalSince1970)
        }) { s in
            power[sqlite3_column_double(s, 0), default: [:]][text(s, 1) ?? ""] =
                Power(cpu: sqlite3_column_double(s, 2), gpu: sqlite3_column_double(s, 3))
        }
        var samples: [Sample] = []
        query("SELECT ts, duration, temp, max_temp, pressure, gpu, front, apps, has_power FROM samples WHERE resolution = ? AND ts >= ? ORDER BY ts", bind: { s in
            sqlite3_bind_int(s, 1, resolution.rawValue)
            sqlite3_bind_double(s, 2, date.timeIntervalSince1970)
        }) { s in
            let ts = sqlite3_column_double(s, 0)
            let apps = text(s, 7).flatMap { try? JSONDecoder().decode([String].self, from: Data($0.utf8)) } ?? []
            samples.append(Sample(
                date: Date(timeIntervalSince1970: ts), duration: sqlite3_column_double(s, 1),
                temp: sqlite3_column_double(s, 2), maxTemp: sqlite3_column_double(s, 3),
                apps: apps, front: text(s, 6),
                power: sqlite3_column_int(s, 8) == 1 ? power[ts] ?? [:] : nil,
                pressure: sqlite3_column_type(s, 4) == SQLITE_NULL ? nil : Int(sqlite3_column_int(s, 4)),
                gpu: sqlite3_column_type(s, 5) == SQLITE_NULL ? nil : sqlite3_column_double(s, 5)))
        }
        return samples
    }

    func loadNames() -> [String: String] {
        var names: [String: String] = [:]
        query("SELECT id, name FROM names", bind: { _ in }) { s in
            if let id = text(s, 0), let name = text(s, 1) { names[id] = name }
        }
        return names
    }

    /// Uma linha por (instante, app); temperatura em °C, potência em W.
    func exportCSV(resolution: Resolution, to url: URL) throws {
        let names = loadNames()
        let samples = load(resolution: resolution, since: .distantPast)
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        var lines = ["timestamp,duracao_s,temp_media_c,temp_max_c,pressao_termica,gpu_total_w,app_id,app,cpu_w,gpu_w,primeiro_plano"]
        func field(_ value: String) -> String {
            value.contains(where: { ",\"\n".contains($0) }) ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" : value
        }
        func number(_ value: Double?) -> String { value.map { String(format: "%.3f", $0) } ?? "" }
        for sample in samples {
            let head = [iso.string(from: sample.date), number(sample.duration), number(sample.temp), number(sample.maxTemp),
                        sample.pressure.map(String.init) ?? "", number(sample.gpu)].joined(separator: ",")
            let power = (sample.power ?? [:]).sorted { $0.value.total > $1.value.total }
            if power.isEmpty { lines.append(head + ",,,,,"); continue }
            for (id, watts) in power {
                lines.append([head, field(id), field(names[id] ?? id), number(watts.cpu), number(watts.gpu),
                              sample.front == id ? "1" : "0"].joined(separator: ","))
            }
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - SQLite

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func run(_ sql: String, bind: (OpaquePointer) -> Void) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return }
        defer { sqlite3_finalize(statement) }
        bind(statement)
        sqlite3_step(statement)
    }

    private func query(_ sql: String, bind: (OpaquePointer) -> Void, row: (OpaquePointer) -> Void) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return }
        defer { sqlite3_finalize(statement) }
        bind(statement)
        while sqlite3_step(statement) == SQLITE_ROW { row(statement) }
    }

    private func bind(_ s: OpaquePointer, _ index: Int32, _ value: Int?) {
        if let value { sqlite3_bind_int(s, index, Int32(value)) } else { sqlite3_bind_null(s, index) }
    }

    private func bind(_ s: OpaquePointer, _ index: Int32, _ value: Double?) {
        if let value { sqlite3_bind_double(s, index, value) } else { sqlite3_bind_null(s, index) }
    }

    private func bind(_ s: OpaquePointer, _ index: Int32, _ value: String?) {
        if let value { sqlite3_bind_text(s, index, value, -1, Self.transient) } else { sqlite3_bind_null(s, index) }
    }

    private func text(_ s: OpaquePointer, _ index: Int32) -> String? {
        sqlite3_column_text(s, index).map { String(cString: $0) }
    }
}
