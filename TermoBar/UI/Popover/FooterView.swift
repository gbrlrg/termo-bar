import SwiftUI

/// Atalho para o Monitor de Atividade e o menu do app.
struct FooterView: View {
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @Environment(\.openSettings) private var openSettings

    private static let activityMonitorURL = URL(filePath: "/System/Applications/Utilities/Activity Monitor.app")

    var body: some View {
        @Bindable var launchAtLogin = launchAtLogin
        HStack {
            Button {
                NSWorkspace.shared.open(Self.activityMonitorURL)
            } label: {
                Label("Monitor de Atividade", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Menu {
                Button("Ajustes…") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                Toggle("Abrir ao iniciar sessão", isOn: $launchAtLogin.isEnabled)
                Divider()
                Button("Sair do TermoBar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 6)
    }
}
