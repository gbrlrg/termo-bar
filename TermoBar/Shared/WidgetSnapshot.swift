import Foundation

/// O que o app publica para o widget, que roda em sandbox e não lê os sensores nem o histórico.
/// Os valores vêm formatados com as preferências do usuário (unidade, casas decimais).
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct App: Codable, Equatable, Sendable, Identifiable {
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

    /// Sem registro há mais que isso, o app provavelmente está fechado e os números estão velhos.
    static let staleInterval: TimeInterval = 15 * 60
    /// De quanto em quanto tempo o widget relê o resumo por conta própria. Quem pede para redesenhar
    /// é o app; isto é só a rede de segurança.
    static let timelineRefresh: TimeInterval = 15 * 60
    /// O macOS limita quantas vezes por dia um widget é redesenhado: no máximo uma vez por minuto.
    static let minimumReloadInterval: TimeInterval = 60
    /// Diferença de temperatura (°C) que justifica redesenhar o widget.
    static let temperatureStep = 1.0

    private static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget.json")
    }

    static func load() -> WidgetSnapshot? {
        fileURL.flatMap(load(from:))
    }

    /// Resumo gravado em `url`; `nil` se o arquivo não existe ou não é um resumo válido.
    static func load(from url: URL) -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() throws {
        guard let url = Self.fileURL else { throw CocoaError(.fileNoSuchFile) }
        try save(to: url)
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    /// Sem registro recente, o app provavelmente está fechado e os números estão velhos.
    func isStale(at now: Date) -> Bool { now.timeIntervalSince(date) > Self.staleInterval }

    var isStale: Bool { isStale(at: .now) }

    /// Vale pedir ao WidgetKit para redesenhar, comparado ao último resumo redesenhado: passou o
    /// intervalo mínimo e algo visível mudou.
    func needsReload(since last: WidgetSnapshot) -> Bool {
        guard date.timeIntervalSince(last.date) >= Self.minimumReloadInterval else { return false }
        // Unidade ou casas decimais trocadas mudam o formato do texto, não só o valor.
        return abs(celsius - last.celsius) >= Self.temperatureStep
            || temperature.count != last.temperature.count
            || temperature.last != last.temperature.last
            || pressure != last.pressure
            || apps.first?.id != last.apps.first?.id
    }

    /// Exemplo da galeria de widgets.
    static let placeholder = WidgetSnapshot(
        date: .now, celsius: 62, temperature: "62 °C", pressure: .nominal,
        apps: [
            App(id: "a", name: "Xcode", watts: "4,2 W", share: 0.48, colorSlot: 0),
            App(id: "b", name: "Safari", watts: "1,9 W", share: 0.22, colorSlot: 1),
            App(id: "c", name: "Mail", watts: "0,6 W", share: 0.07, colorSlot: 2),
        ])
}

extension ThermalPressure: Codable {}
