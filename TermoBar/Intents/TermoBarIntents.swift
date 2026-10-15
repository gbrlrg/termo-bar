import AppIntents

/// Temperatura atual do chip, para Atalhos e Siri.
struct GetTemperatureIntent: AppIntent {
    static let title: LocalizedStringResource = "Obter a temperatura do Mac"
    static let description = IntentDescription("Temperatura atual do chip, como aparece na barra de menus.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let monitor = AppDependencies.monitor
        let preferences = AppDependencies.preferences
        guard let celsius = monitor.currentTemperature else {
            return .result(value: 0, dialog: "O TermoBar ainda não tem uma leitura do chip.")
        }
        let value = preferences.unit.convert(celsius)
        let temperature = preferences.format(celsius)
        let pressure = monitor.pressure.label.lowercased()
        return .result(value: value, dialog: "O chip está a \(temperature), com pressão térmica \(pressure).")
    }
}

/// App que mais gastou energia nos últimos 15 minutos.
struct GetTopAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Obter o app que mais aquece"
    static let description = IntentDescription("App que mais gastou energia nos últimos 15 minutos.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = AppDependencies.monitor.summary(range: .quarter)
        guard let top = summary.rows.first(where: { $0.id != AppID.others && $0.energy.total > 0 }) else {
            return .result(value: "", dialog: "Nenhum app gastou energia nos últimos 15 minutos.")
        }
        let watts = top.average.total.formatted(.watts)
        let share = top.share.formatted(.percent.precision(.fractionLength(0)))
        return .result(
            value: top.name,
            dialog: "\(top.name) é o app que mais aquece: \(watts) em média, \(share) da energia dos apps.")
    }
}

struct TermoBarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTemperatureIntent(),
            phrases: [
                "Temperatura do Mac no \(.applicationName)",
                "Qual a temperatura do Mac no \(.applicationName)",
            ],
            shortTitle: "Temperatura do Mac",
            systemImageName: "thermometer.medium")
        AppShortcut(
            intent: GetTopAppIntent(),
            phrases: [
                "App que mais aquece no \(.applicationName)",
                "Qual app mais aquece no \(.applicationName)",
            ],
            shortTitle: "App que mais aquece",
            systemImageName: "flame")
    }
}
