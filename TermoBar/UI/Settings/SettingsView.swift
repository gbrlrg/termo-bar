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

extension SettingsTab {
    var title: String {
        switch self {
        case .general: "Geral"
        case .menuBar: "Barra de menus"
        case .alerts: "Alertas"
        case .sensors: "Sensores"
        case .data: "Dados"
        case .methodology: "Precisão"
        case .about: "Sobre"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .alerts: "bell.badge"
        case .sensors: "sensor"
        case .data: "externaldrive"
        case .methodology: "scope"
        case .about: "info.circle"
        }
    }

    /// Conteúdo da aba, também usado sozinho nas capturas de tela da documentação.
    @ViewBuilder @MainActor
    var content: some View {
        switch self {
        case .general: GeneralSettingsView()
        case .menuBar: MenuBarSettingsView()
        case .alerts: AlertSettingsView()
        case .sensors: SensorSettingsView()
        case .data: DataSettingsView()
        case .methodology: MethodologyView()
        case .about: AboutView()
        }
    }
}

/// Janela de Ajustes.
struct SettingsView: View {
    /// Largura da janela, igual em todas as abas.
    static let width: CGFloat = 560

    @State var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab) { tab.content }
            }
        }
        // O Form agrupado já tem margens próprias; sem `scenePadding` o espaçamento fica igual ao do macOS.
        .frame(width: Self.width)
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
