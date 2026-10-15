import SwiftUI

struct SensorSettingsView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var monitor = monitor
        Form {
            Section {
                Toggle("Mostrar também sensores fora do chip", isOn: $monitor.showAllSensors)
            } footer: {
                SettingsFootnote(
                    "A temperatura do chip é a média dos sensores do die do SoC. Leituras fora de 10–130 °C ou que destoam mais de 25 °C da mediana são descartadas."
                )
            }
            if !monitor.fans.isEmpty {
                Section {
                    ForEach(monitor.fans) { fan in
                        FanRow(fan: fan, label: fanLabel(fan))
                    }
                } header: {
                    Text("Ventiladores")
                } footer: {
                    SettingsFootnote(
                        "Rotação lida do controlador do sistema (SMC). Parada abaixo de \(Int(Fan.spinningThreshold)) rpm."
                    )
                }
            }
            Section("Leituras ao vivo") {
                ForEach(monitor.sensors) { sensor in
                    SensorRow(sensor: sensor, value: sensor.value.map { preferences.format($0, decimals: 1) })
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 460)
        .onAppear { monitor.isShowingSensors = true }
        .onDisappear { monitor.isShowingSensors = false }
    }

    private func fanLabel(_ fan: Fan) -> String {
        monitor.fans.count == 1 ? String(localized: "Ventilador") : String(localized: "Ventilador \(fan.id + 1)")
    }
}

private struct FanRow: View {
    let fan: Fan
    let label: String

    var body: some View {
        HStack {
            Image(systemName: fan.isSpinning ? "fan.fill" : "fan.slash")
                .foregroundStyle(fan.isSpinning ? Theme.good : Color.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                Text("Mín. \(fan.minimum.formatted(.rpm)) · máx. \(fan.maximum.formatted(.rpm))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(fan.isSpinning ? fan.rpm.formatted(.rpm) : String(localized: "Parado"))
                .monospacedDigit()
        }
    }
}

private struct SensorRow: View {
    let sensor: TemperatureSensors.Sensor
    let value: String?

    var body: some View {
        HStack {
            Image(systemName: sensor.isIncluded ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(sensor.isIncluded ? Theme.good : Color.secondary)
                .help(
                    sensor.isIncluded
                        ? String(localized: "Entra na média do chip") : String(localized: "Fora da média")
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(sensor.label)
                Text(sensor.id).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Text(value ?? String(localized: "sem leitura"))
                .monospacedDigit()
                .foregroundStyle(value == nil ? .tertiary : .primary)
        }
    }
}
