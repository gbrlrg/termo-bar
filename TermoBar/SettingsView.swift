import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let monitor: Monitor
    @State var selection = "geral"

    var body: some View {
        TabView(selection: $selection) {
            Tab("Geral", systemImage: "gearshape", value: "geral") { GeneralSettings() }
            Tab("Barra de menus", systemImage: "menubar.rectangle", value: "barra") { MenuBarSettings(monitor: monitor) }
            Tab("Alertas", systemImage: "bell.badge", value: "alertas") { AlertSettings() }
            Tab("Sensores", systemImage: "sensor", value: "sensores") { SensorSettings(monitor: monitor) }
            Tab("Dados", systemImage: "externaldrive", value: "dados") { DataSettings(monitor: monitor) }
            Tab("Precisão", systemImage: "scope", value: "precisao") { MethodologyView() }
        }
        .frame(width: 520)
        .scenePadding()
    }
}

// MARK: - Geral

private struct GeneralSettings: View {
    @State private var prefs = Preferences.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Picker("Unidade", selection: $prefs.unit) {
                ForEach(TemperatureUnit.allCases) { Text($0.label).tag($0) }
            }
            Picker("Casas decimais", selection: $prefs.decimals) {
                Text("Nenhuma (79°)").tag(0)
                Text("Uma (79,4°)").tag(1)
            }
            Picker("Temperatura exibida", selection: $prefs.source) {
                ForEach(TemperatureSource.allCases) { Text($0.label).tag($0) }
            }
            Text("A média reúne os sensores do die do chip e é a mais estável. O ponto mais quente mostra o sensor de maior leitura e reage mais rápido a picos.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Intervalo de registro", selection: $prefs.sampleInterval) {
                Text("2 segundos").tag(2.0)
                Text("5 segundos").tag(5.0)
                Text("10 segundos").tag(10.0)
            }
            Text("Os sensores são lidos a cada segundo; cada registro guarda a média das leituras do intervalo.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Abrir ao iniciar sessão", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Barra de menus

private struct MenuBarSettings: View {
    let monitor: Monitor
    @State private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Prévia")
                    Spacer()
                    MenuBarLabel(monitor: monitor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            Picker("Mostrar", selection: $prefs.menuBarStyle) {
                ForEach(MenuBarStyle.allCases) { Text($0.label).tag($0) }
            }
            Toggle("Colorir a temperatura quando estiver quente", isOn: $prefs.colorWhenHot)
            Toggle("Mostrar só o ícone enquanto estiver frio", isOn: $prefs.compactWhenCool)
            if prefs.compactWhenCool {
                TemperatureStepper(title: "Mostrar a temperatura a partir de", celsius: $prefs.compactThreshold)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Alertas

private struct AlertSettings: View {
    @State private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Temperatura alta", isOn: $prefs.alertTemperature)
                if prefs.alertTemperature {
                    TemperatureStepper(title: "Avisar acima de", celsius: $prefs.alertTemperatureLimit)
                    Text("O aviso sai quando a temperatura fica acima do limite por 30 segundos seguidos.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Limitação de desempenho", isOn: $prefs.alertThrottling)
                Text("Avisa quando o macOS reduz a velocidade do chip por calor (pressão térmica pesada ou crítica).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("App gastando demais", isOn: $prefs.alertAppPower)
                if prefs.alertAppPower {
                    Stepper(value: $prefs.alertAppWatts, in: 1...60, step: 1) {
                        LabeledContent("Acima de", value: formatWatts(prefs.alertAppWatts))
                    }
                    Stepper(value: $prefs.alertAppMinutes, in: 2...60, step: 1) {
                        LabeledContent("Em média por", value: "\(Int(prefs.alertAppMinutes)) min")
                    }
                }
            }
            Section {
                Button("Enviar notificação de teste") {
                    let alerts = Alerts()
                    alerts.requestAuthorization()
                    let content = UNMutableNotificationContent()
                    content.title = "TermoBar"
                    content.body = "As notificações estão funcionando."
                    UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: nil))
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: [prefs.alertTemperature, prefs.alertThrottling, prefs.alertAppPower]) { _, values in
            if values.contains(true) { Alerts().requestAuthorization() }
        }
    }
}

// MARK: - Sensores

private struct SensorSettings: View {
    let monitor: Monitor
    @State private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Mostrar também sensores fora do chip", isOn: Binding(
                    get: { monitor.showAllSensors }, set: { monitor.showAllSensors = $0 }))
            } footer: {
                Text("A temperatura do chip é a média dos sensores do die do SoC. Leituras fora de 10–130 °C ou que destoam mais de 25 °C da mediana são descartadas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Leituras ao vivo") {
                ForEach(monitor.sensors) { sensor in
                    HStack {
                        Image(systemName: sensor.included ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(sensor.included ? Theme.good : Color.secondary)
                            .help(sensor.included ? "Entra na média do chip" : "Fora da média")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sensor.label)
                            Text(sensor.id).font(.caption).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(sensor.value.map { prefs.format($0, decimals: 1) } ?? "sem leitura")
                            .monospacedDigit()
                            .foregroundStyle(sensor.value == nil ? .tertiary : .primary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 460)
    }
}

// MARK: - Dados

private struct DataSettings: View {
    let monitor: Monitor
    @State private var prefs = Preferences.shared
    @State private var confirmClear = false
    @State private var message: String?

    var body: some View {
        Form {
            Picker("Guardar histórico por", selection: $prefs.retentionDays) {
                Text("7 dias").tag(7)
                Text("30 dias").tag(30)
                Text("90 dias").tag(90)
            }
            Text("As leituras finas ficam 24 horas; depois disso fica o resumo por minuto. Tudo fica só neste Mac, sem envio de dados.")
                .font(.caption).foregroundStyle(.secondary)
            Section("Exportar CSV") {
                Button("Últimas 24 horas, leitura a leitura…") { export(.raw, name: "TermoBar-24h.csv") }
                Button("Histórico completo, por minuto…") { export(.minute, name: "TermoBar-historico.csv") }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            Section {
                Button("Mostrar no Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([
                        URL.applicationSupportDirectory.appending(path: "TermoBar/history.sqlite"),
                    ])
                }
                Button("Apagar histórico…", role: .destructive) { confirmClear = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Apagar todo o histórico?", isPresented: $confirmClear) {
            Button("Apagar", role: .destructive) { monitor.clearHistory() }
        } message: {
            Text("Os gráficos recomeçam do zero. Não dá para desfazer.")
        }
    }

    private func export(_ resolution: Store.Resolution, name: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try monitor.store.exportCSV(resolution: resolution, to: url)
            message = "Exportado para \(url.lastPathComponent)."
        } catch {
            message = "Não foi possível exportar: \(error.localizedDescription)"
        }
    }
}

// MARK: - Precisão

private struct MethodologyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                item("Temperatura", "Lida direto dos sensores do die do chip, a cada segundo, sem privilégio de administrador. Cada registro é a média das leituras do intervalo, o que tira o ruído sem esconder picos: o ponto mais quente é guardado à parte.")
                item("Energia de CPU por app", "Contador de energia que o próprio kernel mantém para cada processo, em joules físicos — não é uma estimativa como o \"Impacto de Energia\" do Monitor de Atividade. Um núcleo de desempenho a 100% marca cerca de 6,5 W num M5.")
                item("Energia de GPU por app", "A energia total da GPU, medida pelo chip, é dividida entre os processos na proporção do tempo de GPU que cada um usou no intervalo.")
                item("Agrupamento", "Cada processo conta para o app responsável por ele, como no Monitor de Atividade: helpers do navegador vão para o navegador, compiladores lançados no terminal vão para o terminal.")
                item("Limites", "A CPU de processos do sistema que rodam como administrador (como o kernel) não é legível sem privilégio e fica de fora. A GPU do WindowServer, que desenha a tela, entra na conta.")
                item("Limitação térmica", "Vem da pressão térmica publicada pelo kernel. A partir do nível \"pesada\" o macOS reduz a frequência do chip; esses trechos aparecem destacados no gráfico.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
        .frame(minHeight: 380)
    }

    private func item(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Peças

/// Stepper que edita um limite guardado em °C, exibindo na unidade escolhida.
private struct TemperatureStepper: View {
    let title: String
    @Binding var celsius: Double
    @State private var prefs = Preferences.shared

    var body: some View {
        Stepper {
            LabeledContent(title, value: prefs.format(celsius, decimals: 0))
        } onIncrement: {
            celsius = min(prefs.unit.toCelsius(prefs.unit.convert(celsius).rounded() + 1), 120)
        } onDecrement: {
            celsius = max(prefs.unit.toCelsius(prefs.unit.convert(celsius).rounded() - 1), 30)
        }
    }
}

import UserNotifications
