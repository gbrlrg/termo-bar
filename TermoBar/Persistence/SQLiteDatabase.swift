import Foundation
import SQLite3

struct SQLiteError: Error, CustomStringConvertible {
    let code: Int32
    let message: String

    var description: String { "SQLite \(code): \(message)" }
}

/// Valor ligado a um parâmetro `?` de uma instrução.
enum SQLiteValue: Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case null

    static func integer(_ value: Int?) -> SQLiteValue { value.map { .integer(Int64($0)) } ?? .null }
    static func real(_ value: Double?) -> SQLiteValue { value.map { .real($0) } ?? .null }
    static func text(_ value: String?) -> SQLiteValue { value.map { .text($0) } ?? .null }
}

/// Conexão SQLite mínima: instruções preparadas com parâmetros tipados e transações.
///
/// Todo valor vindo de fora entra por parâmetro (`?`), nunca interpolado no SQL.
final class SQLiteDatabase {
    private let handle: OpaquePointer

    /// Abre (ou cria) o banco em `path`; `":memory:"` cria um banco temporário em memória.
    init(path: String) throws {
        var handle: OpaquePointer?
        let status = sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard status == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "não foi possível abrir"
            sqlite3_close(handle)
            throw SQLiteError(code: status, message: message)
        }
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }

    /// Executa um script sem parâmetros (uma ou mais instruções separadas por `;`).
    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(handle, sql, nil, nil, &error)
        defer { sqlite3_free(error) }
        guard status == SQLITE_OK else {
            throw SQLiteError(code: status, message: error.map { String(cString: $0) } ?? lastErrorMessage)
        }
    }

    func prepare(_ sql: String) throws -> SQLiteStatement {
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else { throw error(status) }
        return SQLiteStatement(handle: statement, database: self)
    }

    /// Executa uma instrução que não devolve linhas.
    func run(_ sql: String, _ values: [SQLiteValue] = []) throws {
        try prepare(sql).run(values)
    }

    /// Executa uma consulta e chama `row` para cada linha devolvida.
    func query(_ sql: String, _ values: [SQLiteValue] = [], row: (SQLiteStatement) throws -> Void) throws {
        let statement = try prepare(sql)
        try statement.bind(values)
        while try statement.step() { try row(statement) }
    }

    /// Agrupa as escritas de `body`: ou todas são gravadas, ou nenhuma.
    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    fileprivate var lastErrorMessage: String { String(cString: sqlite3_errmsg(handle)) }

    fileprivate func error(_ status: Int32) -> SQLiteError {
        SQLiteError(code: status, message: lastErrorMessage)
    }
}

/// Instrução preparada; pode ser reutilizada com novos parâmetros.
final class SQLiteStatement {
    /// Pede ao SQLite que copie o texto ligado (`SQLITE_TRANSIENT`, que não é importado pelo Swift).
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let handle: OpaquePointer
    private let database: SQLiteDatabase

    fileprivate init(handle: OpaquePointer, database: SQLiteDatabase) {
        self.handle = handle
        self.database = database
    }

    deinit {
        sqlite3_finalize(handle)
    }

    func bind(_ values: [SQLiteValue]) throws {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let status =
                switch value {
                case .integer(let integer): sqlite3_bind_int64(handle, index, integer)
                case .real(let real): sqlite3_bind_double(handle, index, real)
                case .text(let text): sqlite3_bind_text(handle, index, text, -1, Self.transient)
                case .null: sqlite3_bind_null(handle, index)
                }
            guard status == SQLITE_OK else { throw database.error(status) }
        }
    }

    /// Avança uma linha; `false` quando a instrução terminou.
    func step() throws -> Bool {
        switch sqlite3_step(handle) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        case let status: throw database.error(status)
        }
    }

    func run(_ values: [SQLiteValue] = []) throws {
        try bind(values)
        while try step() {}
    }

    // MARK: - Colunas da linha atual

    func isNull(_ column: Int32) -> Bool { sqlite3_column_type(handle, column) == SQLITE_NULL }

    func double(_ column: Int32) -> Double { sqlite3_column_double(handle, column) }

    func integer(_ column: Int32) -> Int { Int(sqlite3_column_int64(handle, column)) }

    func text(_ column: Int32) -> String? { sqlite3_column_text(handle, column).map { String(cString: $0) } }

    func optionalDouble(_ column: Int32) -> Double? { isNull(column) ? nil : double(column) }

    func optionalInteger(_ column: Int32) -> Int? { isNull(column) ? nil : integer(column) }
}
