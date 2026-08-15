import SwiftUI
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences
    @State private var isConfirmingClear = false
    @State private var exportMessage: String?

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Picker("Guardar histórico por", selection: $preferences.retentionDays) {
                Text("7 dias").tag(7)
                Text("30 dias").tag(30)
                Text("90 dias").tag(90)
            }
            SettingsFootnote(
                "As leituras finas ficam 24 horas; depois disso fica o resumo por minuto. Tudo fica só neste Mac, sem envio de dados."
            )
            Section("Exportar CSV") {
                Button("Últimas 24 horas, leitura a leitura…") { export(.raw, fileName: "TermoBar-24h.csv") }
                Button("Histórico completo, por minuto…") { export(.minute, fileName: "TermoBar-historico.csv") }
                if let exportMessage { SettingsFootnote(exportMessage) }
            }
            Section {
                Button("Mostrar no Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.defaultURL])
                }
                Button("Apagar histórico…", role: .destructive) { isConfirmingClear = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Apagar todo o histórico?", isPresented: $isConfirmingClear) {
            Button("Apagar", role: .destructive) { monitor.clearHistory() }
        } message: {
            Text("Os gráficos recomeçam do zero. Não dá para desfazer.")
        }
    }

    private func export(_ resolution: HistoryStore.Resolution, fileName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try monitor.exportCSV(resolution: resolution, to: url)
            exportMessage = "Exportado para \(url.lastPathComponent)."
        } catch {
            exportMessage = "Não foi possível exportar: \(error.localizedDescription)"
        }
    }
}
