import SwiftUI

struct GeneralSettingsView: View {
    @Environment(Preferences.self) private var preferences
    @Environment(LaunchAtLogin.self) private var launchAtLogin

    var body: some View {
        @Bindable var preferences = preferences
        @Bindable var launchAtLogin = launchAtLogin
        Form {
            Section {
                Toggle("Abrir no início da sessão", isOn: $launchAtLogin.isEnabled)
            }
            Section {
                Picker("Temperatura exibida", selection: $preferences.source) {
                    ForEach(TemperatureSource.allCases) { Text($0.label).tag($0) }
                }
                Picker("Unidade", selection: $preferences.unit) {
                    ForEach(TemperatureUnit.allCases) { Text($0.label).tag($0) }
                }
                Picker("Casas decimais", selection: $preferences.decimals) {
                    Text("Nenhuma (79°)").tag(0)
                    Text("Uma (79,4°)").tag(1)
                }
            } footer: {
                SettingsFootnote(
                    "A média reúne os sensores do die do chip e é a mais estável. O ponto mais quente mostra o sensor de maior leitura e reage mais rápido a picos."
                )
            }
            Section {
                Picker("Intervalo de registro", selection: $preferences.sampleInterval) {
                    Text("2 segundos").tag(2.0)
                    Text("5 segundos").tag(5.0)
                    Text("10 segundos").tag(10.0)
                }
            } footer: {
                SettingsFootnote(
                    "Os sensores são lidos a cada segundo; cada registro guarda a média das leituras do intervalo.")
            }
        }
        .formStyle(.grouped)
    }
}
