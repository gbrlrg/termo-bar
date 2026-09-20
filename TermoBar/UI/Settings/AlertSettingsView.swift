import SwiftUI

struct AlertSettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(AlertNotifier.self) private var alerts

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            if alerts.isDenied {
                Section {
                    Label("Notificações desativadas", systemImage: "bell.slash.fill")
                        .foregroundStyle(Theme.critical)
                    SettingsFootnote(
                        "O macOS está bloqueando as notificações do TermoBar, e os alertas não vão aparecer.")
                    Button("Abrir Ajustes de Notificações") {
                        if let url = Self.notificationSettingsURL { NSWorkspace.shared.open(url) }
                    }
                }
            }
            Section {
                Toggle("Temperatura alta", isOn: $preferences.alertTemperature)
                if preferences.alertTemperature {
                    TemperatureStepper(title: "Avisar acima de", celsius: $preferences.alertTemperatureLimit)
                    SettingsFootnote("O aviso sai quando a temperatura fica acima do limite por 30 segundos seguidos.")
                }
            }
            Section {
                Toggle("Limitação de desempenho", isOn: $preferences.alertThrottling)
                SettingsFootnote(
                    "Avisa quando o macOS reduz a velocidade do chip por calor (pressão térmica pesada ou crítica).")
            }
            Section {
                Toggle("App gastando demais", isOn: $preferences.alertAppPower)
                if preferences.alertAppPower {
                    Stepper(value: $preferences.alertAppWatts, in: Preferences.appWattsRange, step: 1) {
                        LabeledContent("Acima de", value: preferences.alertAppWatts.formatted(.watts))
                    }
                    Stepper(value: $preferences.alertAppMinutes, in: Preferences.appMinutesRange, step: 1) {
                        LabeledContent("Em média por", value: "\(Int(preferences.alertAppMinutes)) min")
                    }
                }
            }
            Section {
                Button("Enviar notificação de teste") { alerts.sendTestNotification() }
            }
        }
        .formStyle(.grouped)
        .onChange(of: preferences.alertConfiguration.isAnyEnabled) { _, isEnabled in
            if isEnabled { alerts.requestAuthorization() }
        }
        // Atualiza ao abrir a aba e ao voltar dos Ajustes do Sistema.
        .task { await alerts.refreshAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await alerts.refreshAuthorization() }
        }
    }

    private static let notificationSettingsURL = URL(
        string:
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")"
    )
}
