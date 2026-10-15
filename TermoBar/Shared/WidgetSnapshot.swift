import Foundation

/// O que o app publica para o widget, que roda em sandbox e não lê os sensores nem o histórico.
/// Os valores vêm formatados com as preferências do usuário (unidade, casas decimais).
struct WidgetSnapshot: Codable, Sendable {
    struct App: Codable, Sendable, Identifiable {
        let id: String
        let name: String
        let watts: String
        /// Fatia da energia dos apps nos últimos 15 minutos (0–1).
        let share: Double
        /// Posição na paleta do gráfico de energia, para o widget usar a mesma cor.
        let colorSlot: Int?
    }

    let date: Date
    let celsius: Double
    let temperature: String
    let pressure: ThermalPressure
    let apps: [App]

    /// Grupo com o prefixo do time: dispensa perfil de provisionamento no macOS.
    static let appGroup = "F22LFNZSAZ.br.com.gbrlrg.termobar"
    static let kind = "TermoBarWidget"

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget.json")
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() throws {
        guard let url = Self.fileURL else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

extension ThermalPressure: Codable {}
