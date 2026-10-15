import SwiftUI

/// Temperatura atual em destaque, estado térmico e números de apoio.
struct HeaderView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(Preferences.self) private var preferences
    let summary: RangeSummary

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(monitor.chipName) · \(preferences.source.label.lowercased())")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                currentTemperature
                // Com "Limitando desempenho", o selo da ventoinha desce para a linha de baixo.
                FlowLayout(spacing: 6) {
                    PressureBadge(pressure: monitor.pressure)
                    if let rpm = monitor.current?.fanSpeed {
                        FanBadge(rpm: rpm)
                    }
                    // Ligado, avisa; desligado, só aparece como sugestão quando o Mac já está sob pressão.
                    if monitor.isLowPowerMode || monitor.pressure >= .moderate {
                        LowPowerBadge(isOn: monitor.isLowPowerMode)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                if let current = monitor.current {
                    let alternate = preferences.source.alternate
                    Stat(title: "\(alternate.label)", value: preferences.format(current.temperature(for: alternate)))
                }
                Stat(title: "Apps agora", value: monitor.currentPower?.formatted(.watts) ?? "—")
                Stat(title: "Mín · Máx", value: temperatureRange ?? "—")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
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

    private var temperatureRange: String? {
        let temperatures = summary.samples.map(monitor.temperature(of:))
        guard let low = temperatures.min(), let high = temperatures.max() else { return nil }
        return "\(preferences.short(low)) · \(preferences.short(high))"
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
        .font(.caption.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.fill.tertiary, in: Capsule())
        .fixedSize()
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(pressure.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(pressure.color.opacity(0.14), in: Capsule())
            .fixedSize()
            .help("Pressão térmica informada pelo kernel do macOS")
    }
}
