import Foundation

/// Abas da janela de Ajustes; o valor bruto é o nome usado em `TERMOBAR_SETTINGS_TAB`.
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
        case .general: String(localized: "Geral")
        case .menuBar: String(localized: "Barra de menus")
        case .alerts: String(localized: "Alertas")
        case .sensors: String(localized: "Sensores")
        case .data: String(localized: "Dados")
        case .methodology: String(localized: "Precisão")
        case .about: String(localized: "Sobre")
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
}
