import os

/// Canais do log unificado (Console.app, `log stream --predicate 'subsystem == "br.com.gbrlrg.termobar"'`).
enum Log {
    private static let subsystem = "br.com.gbrlrg.termobar"

    static let history = Logger(subsystem: subsystem, category: "history")
    static let notifications = Logger(subsystem: subsystem, category: "notifications")
    static let system = Logger(subsystem: subsystem, category: "system")
}
