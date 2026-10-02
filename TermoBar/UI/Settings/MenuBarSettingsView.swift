import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                LabeledContent("Prévia") {
                    MenuBarLabel()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            Section {
                Picker("Mostrar", selection: $preferences.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                Toggle("Colorir a temperatura quando estiver quente", isOn: $preferences.colorWhenHot)
            } footer: {
                SettingsFootnote("A partir de \(preferences.format(Theme.hotTemperature, decimals: 0)).")
            }
            Section {
                Toggle("Mostrar só o ícone enquanto estiver frio", isOn: $preferences.compactWhenCool)
                if preferences.compactWhenCool {
                    TemperatureStepper(
                        title: "Mostrar a temperatura a partir de", celsius: $preferences.compactThreshold)
                }
            }
        }
        .formStyle(.grouped)
    }
}
