import SwiftUI

/// Atalho para o Monitor de Atividade e o menu do app.
struct FooterView: View {
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @Environment(Updater.self) private var updater
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

            if let version = updater.pendingVersion {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Atualizar", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .help("Versão \(version) disponível")
                .padding(.trailing, 8)
            }

            Menu {
                Button("Ajustes…") {
                    NSApp.activate()
                    openSettings()
                }
                .keyboardShortcut(",")
                Button("Buscar Atualizações…") { updater.checkForUpdates() }
                Toggle("Abrir no início da sessão", isOn: $launchAtLogin.isEnabled)
                Divider()
                Button("Encerrar TermoBar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Label("Ajustes", systemImage: "gearshape")
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
