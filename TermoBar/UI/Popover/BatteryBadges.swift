import SwiftUI

/// Carga da bateria e, quando o sensor existe, a temperatura dela; carregando é quando ela mais esquenta.
struct BatteryBadge: View {
    let battery: BatteryStatus
    let temperature: String?

    var body: some View {
        Label(text, systemImage: symbol)
            .badgeStyle()
            .help(help)
    }

    private var text: String {
        let percent = "\(battery.percent)%"
        return temperature.map { "\(percent) · \($0)" } ?? percent
    }

    private var symbol: String {
        if battery.isCharging { return "battery.100percent.bolt" }
        return switch battery.percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private var help: String {
        let state =
            battery.isCharging
            ? String(localized: "carregando")
            : battery.isPluggedIn ? String(localized: "na tomada") : String(localized: "na bateria")
        return temperature == nil
            ? String(localized: "Carga da bateria, \(state)")
            : String(localized: "Carga e temperatura da bateria, \(state)")
    }
}

/// Quanto falta para a bateria acabar (no ritmo atual) ou para carregar.
struct BatteryTimeBadge: View {
    let battery: BatteryStatus
    let runtime: RuntimeEstimate?

    var body: some View {
        if let content {
            Label(content.text, systemImage: "clock")
                .badgeStyle()
                .help(content.help)
        }
    }

    private var content: (text: String, help: String)? {
        if battery.isDischarging { return runtimeContent }
        if let minutes = battery.minutesToFull {
            return (
                String(localized: "Cheia em \(Self.format(minutes: minutes))"),
                String(localized: "Tempo para completar a carga, estimado pelo macOS")
            )
        }
        return nil
    }

    private var runtimeContent: (text: String, help: String) {
        guard let runtime else {
            return (
                String(localized: "Calculando…"),
                String(localized: "A autonomia aparece depois de alguns minutos de medição na bateria")
            )
        }
        let text =
            runtime.exceedsDisplayLimit
            ? String(localized: "mais de 24 h") : "~" + Self.format(minutes: runtime.roundedMinutes)
        let minutes = Int((runtime.basis / 60).rounded())
        return (
            text,
            String(
                localized:
                    "Autonomia no ritmo dos últimos \(minutes) min (\(runtime.watts.formatted(.watts))). Muda conforme o que você faz."
            )
        )
    }

    private static func format(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}

extension View {
    /// Pílula cinza dos números de apoio do cabeçalho.
    fileprivate func badgeStyle() -> some View {
        font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.fill.tertiary, in: Capsule())
            .fixedSize()
    }
}
