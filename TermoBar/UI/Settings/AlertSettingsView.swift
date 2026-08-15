import SwiftUI

struct AlertSettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(AlertNotifier.self) private var alerts

    var body: some View {
        @Bindable var preferences = preferences
        Form {
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
    }
}
