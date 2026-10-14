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
            Section {
                Picker("Guardar histórico por", selection: $preferences.retentionDays) {
                    Text("7 dias").tag(7)
                    Text("30 dias").tag(30)
                    Text("90 dias").tag(90)
                }
            } footer: {
                SettingsFootnote(
                    "As leituras finas ficam 24 horas; depois disso fica o resumo por minuto. Tudo fica só neste Mac, sem envio de dados."
                )
            }
            Section {
                LabeledContent("Últimas 24 horas, leitura a leitura") {
                    Button("Exportar…") { export(.raw, fileName: "TermoBar-24h.csv") }
                }
                LabeledContent("Histórico completo, por minuto") {
                    Button("Exportar…") { export(.minute, fileName: "TermoBar-historico.csv") }
                }
            } header: {
                Text("Exportar CSV")
            } footer: {
                if let exportMessage { SettingsFootnote(verbatim: exportMessage) }
            }
            Section("Histórico neste Mac") {
                LabeledContent("Arquivo do histórico") {
                    Button("Mostrar no Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.defaultURL])
                    }
                }
                LabeledContent("Apagar todas as leituras") {
                    Button(role: .destructive) {
                        isConfirmingClear = true
                    } label: {
                        Text("Apagar…").foregroundStyle(Theme.critical)
                    }
                }
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
            exportMessage = String(localized: "Exportado para \(url.lastPathComponent).")
        } catch {
            exportMessage = String(localized: "Não foi possível exportar: \(error.localizedDescription)")
        }
    }
}
