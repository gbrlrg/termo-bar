import SwiftUI

/// Temperatura atual em destaque, estado térmico e números de apoio.
struct HeaderView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    /// Período do popover: as médias dos detalhes usam as mesmas amostras dos gráficos.
    let summary: RangeSummary

    @State private var expanded: BadgeKind? = {
        #if DEBUG
            ProcessInfo.processInfo.environment["TERMOBAR_BADGE"].flatMap {
                ["pressure": BadgeKind.pressure, "fan": .fan, "battery": .battery][$0]
            }
        #else
            nil
        #endif
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(monitor.chipName) · \(preferences.source.label.lowercased())")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    currentTemperature
                }
                Spacer()
                // Só os números do instante; mínimo e máximo do período ficam no gráfico de temperatura.
                VStack(alignment: .trailing, spacing: 10) {
                    if let current = monitor.current {
                        let alternate = preferences.source.alternate
                        Stat(
                            title: "\(alternate.label)", value: preferences.format(current.temperature(for: alternate)))
                    }
                    Stat(title: "Apps agora", value: monitor.currentPower?.formatted(.watts) ?? "—")
                }
                .padding(.top, 2)
            }
            FlowLayout(spacing: 6) {
                BadgeButton(isExpanded: expanded == .pressure, tint: monitor.pressure.color) {
                    toggle(.pressure)
                } label: {
                    PressureBadge(pressure: monitor.pressure)
                }
                if let rpm = monitor.current?.fanSpeed {
                    BadgeButton(isExpanded: expanded == .fan) {
                        toggle(.fan)
                    } label: {
                        FanBadge(rpm: rpm)
                    }
                }
                if let battery = monitor.battery {
                    BadgeButton(isExpanded: expanded == .battery) {
                        toggle(.battery)
                    } label: {
                        BatteryBadge(battery: battery, temperature: batteryTemperature)
                    }
                    if BatteryTimeBadge.hasContent(battery) {
                        BadgeButton(isExpanded: expanded == .battery) {
                            toggle(.battery)
                        } label: {
                            BatteryTimeBadge(battery: battery, runtime: monitor.runtime)
                        }
                    }
                }
                // Ligado, avisa; desligado, só aparece como sugestão quando o Mac já está sob pressão.
                if monitor.isLowPowerMode || monitor.pressure >= .moderate {
                    LowPowerBadge(isOn: monitor.isLowPowerMode)
                }
            }
            if let detail {
                detail.padding(.horizontal, -4).transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
    }

    private var batteryTemperature: String? {
        monitor.batteryTemperature.map { preferences.format($0, decimals: 0) }
    }

    private func toggle(_ kind: BadgeKind) {
        withAnimation(.smooth(duration: 0.25)) { expanded = expanded == kind ? nil : kind }
    }

    /// Detalhes do badge aberto; fecham sozinhos se o dado some (bateria desligada, ventoinha sem leitura).
    private var detail: BadgeDetailCard? {
        switch expanded {
        case .pressure:
            BadgeDetails.pressure(monitor.pressure, samples: summary.samples)
        case .fan:
            monitor.current?.fanSpeed.map { BadgeDetails.fan(rpm: $0, samples: summary.samples) }
        case .battery:
            monitor.battery.map { BadgeDetails.battery($0, temperature: batteryTemperature) }
        case nil:
            nil
        }
    }

    private var currentTemperature: some View {
        let temperature = monitor.currentTemperature
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            // Sem `contentTransition(.numericText)`: o desfoque dos dígitos é calculado na CPU e, a cada
            // registro, custava mais que todo o resto do popover.
            Text(temperature.map { preferences.format($0, symbol: false) } ?? "--")
                .font(.system(size: 44, weight: .semibold))
            Text(preferences.unit.symbol)
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
    }
}

/// Ventoinha parada ou girando, com a rotação média do último registro.
private struct FanBadge: View {
    let rpm: Double

    private var isSpinning: Bool { rpm >= Fan.spinningThreshold }

    var body: some View {
        Label(
            isSpinning ? rpm.formatted(.rpm) : String(localized: "Parado"),
            systemImage: isSpinning ? "fan.fill" : "fan.slash"
        )
        .help(isSpinning ? String(localized: "Ventilador girando") : String(localized: "Ventilador parado"))
    }
}

/// Modo Pouca Energia: abre os Ajustes da Bateria (em Macs de mesa, Energia), onde ele é ligado.
private struct LowPowerBadge: View {
    let isOn: Bool

    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")

    var body: some View {
        Button {
            if let url = Self.settingsURL { NSWorkspace.shared.open(url) }
        } label: {
            Label(isOn ? "Pouca Energia" : "Ativar Pouca Energia", systemImage: isOn ? "leaf.fill" : "leaf")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOn ? Theme.warning : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isOn ? Theme.warning.opacity(0.14) : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(.quaternary, lineWidth: isOn ? 0 : 1))
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(
            isOn
                ? String(localized: "Modo Pouca Energia ativado: o chip esquenta menos. Clique para abrir os Ajustes.")
                : String(localized: "O Modo Pouca Energia reduz o calor e o ruído. Clique para ativar nos Ajustes."))
    }
}

private struct PressureBadge: View {
    let pressure: ThermalPressure

    var body: some View {
        Label(pressure.label, systemImage: pressure.symbol)
            .help("Pressão térmica informada pelo kernel do macOS")
    }
}
