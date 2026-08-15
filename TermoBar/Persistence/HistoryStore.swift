import Foundation

/// Histórico em SQLite: leituras finas e resumos por minuto, com a potência de cada app.
final class HistoryStore {
    enum Resolution: Int, Sendable {
        case raw = 0
        case minute = 1
    }

    private static let schema = """
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
        """

    private let db: SQLiteDatabase

    /// Abre o histórico em `url`, criando a pasta (visível só para o usuário) se preciso.
    convenience init(url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try self.init(database: SQLiteDatabase(path: url.path(percentEncoded: false)))
    }

    /// Histórico temporário, só em memória.
    static func inMemory() throws -> HistoryStore {
        try HistoryStore(database: SQLiteDatabase(path: ":memory:"))
    }

    private init(database: SQLiteDatabase) throws {
        db = database
        try db.execute(Self.schema)
    }

    // MARK: - Escrita

    func insert(_ sample: Sample, resolution: Resolution) throws {
        let timestamp = sample.date.timeIntervalSince1970
        let apps = String(decoding: try JSONEncoder().encode(sample.openApps), as: UTF8.self)
        try db.transaction {
            try db.run(
                "INSERT OR REPLACE INTO samples VALUES(?,?,?,?,?,?,?,?,?,?)",
                [
                    .real(timestamp), .integer(resolution.rawValue), .real(sample.duration),
                    .real(sample.averageTemperature), .real(sample.maxTemperature), .integer(sample.pressure),
                    .real(sample.gpuPower), .text(sample.frontmostApp), .text(apps),
                    .integer(sample.appPower == nil ? 0 : 1),
                ])
            let insertPower = try db.prepare("INSERT INTO app_power VALUES(?,?,?,?,?)")
            for (app, power) in sample.appPower ?? [:] {
                try insertPower.run([
                    .real(timestamp), .integer(resolution.rawValue), .text(app), .real(power.cpu), .real(power.gpu),
                ])
            }
        }
    }

    func saveNames(_ names: [String: String]) throws {
        try db.transaction {
            let statement = try db.prepare("INSERT OR REPLACE INTO names VALUES(?,?)")
            for (id, name) in names {
                try statement.run([.text(id), .text(name)])
            }
        }
    }

    func prune(resolution: Resolution, before date: Date) throws {
        let values: [SQLiteValue] = [.integer(resolution.rawValue), .real(date.timeIntervalSince1970)]
        try db.transaction {
            try db.run("DELETE FROM samples WHERE resolution = ? AND ts < ?", values)
            try db.run("DELETE FROM app_power WHERE resolution = ? AND ts < ?", values)
        }
    }

    /// Apaga tudo e compacta o arquivo, para que os dados apagados não fiquem no disco.
    func deleteAll() throws {
        try db.transaction {
            try db.execute("DELETE FROM samples; DELETE FROM app_power; DELETE FROM names;")
        }
        try db.execute("VACUUM; PRAGMA wal_checkpoint(TRUNCATE);")
    }

    // MARK: - Leitura

    /// Amostras desde `date`, em ordem cronológica.
    func samples(resolution: Resolution, since date: Date) throws -> [Sample] {
        let filter: [SQLiteValue] = [.integer(resolution.rawValue), .real(date.timeIntervalSince1970)]

        var power: [Double: [String: Power]] = [:]
        try db.query("SELECT ts, app, cpu, gpu FROM app_power WHERE resolution = ? AND ts >= ?", filter) { row in
            guard let app = row.text(1) else { return }
            power[row.double(0), default: [:]][app] = Power(cpu: row.double(2), gpu: row.double(3))
        }

        var samples: [Sample] = []
        let decoder = JSONDecoder()
        try db.query(
            """
            SELECT ts, duration, temp, max_temp, pressure, gpu, front, apps, has_power
            FROM samples WHERE resolution = ? AND ts >= ? ORDER BY ts
            """, filter
        ) { row in
            let timestamp = row.double(0)
            let apps = row.text(7).flatMap { try? decoder.decode([String].self, from: Data($0.utf8)) } ?? []
            samples.append(
                Sample(
                    date: Date(timeIntervalSince1970: timestamp),
                    duration: row.double(1),
                    averageTemperature: row.double(2),
                    maxTemperature: row.double(3),
                    openApps: apps,
                    frontmostApp: row.text(6),
                    appPower: row.integer(8) == 1 ? power[timestamp] ?? [:] : nil,
                    pressure: row.optionalInteger(4),
                    gpuPower: row.optionalDouble(5)))
        }
        return samples
    }

    /// Nome de exibição de cada app já visto.
    func names() throws -> [String: String] {
        var names: [String: String] = [:]
        try db.query("SELECT id, name FROM names") { row in
            if let id = row.text(0), let name = row.text(1) { names[id] = name }
        }
        return names
    }

    /// Exporta todo o histórico da resolução em CSV (veja `CSVExporter`).
    func exportCSV(resolution: Resolution, to url: URL) throws {
        let csv = CSVExporter.csv(
            samples: try samples(resolution: resolution, since: .distantPast), names: try names())
        try Data(csv.utf8).write(to: url, options: .atomic)
    }
}
