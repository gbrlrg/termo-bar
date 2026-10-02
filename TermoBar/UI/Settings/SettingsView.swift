import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "geral"
    case menuBar = "barra"
    case alerts = "alertas"
    case sensors = "sensores"
    case data = "dados"
    case methodology = "precisao"
    case about = "sobre"
}

/// Janela de Ajustes.
struct SettingsView: View {
    @State var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            Tab("Geral", systemImage: "gearshape", value: .general) { GeneralSettingsView() }
            Tab("Barra de menus", systemImage: "menubar.rectangle", value: .menuBar) { MenuBarSettingsView() }
            Tab("Alertas", systemImage: "bell.badge", value: .alerts) { AlertSettingsView() }
            Tab("Sensores", systemImage: "sensor", value: .sensors) { SensorSettingsView() }
            Tab("Dados", systemImage: "externaldrive", value: .data) { DataSettingsView() }
            Tab("Precisão", systemImage: "scope", value: .methodology) { MethodologyView() }
            Tab("Sobre", systemImage: "info.circle", value: .about) { AboutView() }
        }
        // O Form agrupado já tem margens próprias; sem `scenePadding` o espaçamento fica igual ao do macOS.
        .frame(width: 560)
    }
}

/// Texto de apoio abaixo de um controle.
struct SettingsFootnote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
