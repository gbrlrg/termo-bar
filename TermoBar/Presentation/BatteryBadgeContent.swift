import Foundation

/// Textos dos badges da bateria no cabeçalho do popover.
enum BatteryBadgeContent {
    /// "carregando", "na tomada" ou "na bateria".
    static func state(_ battery: BatteryStatus) -> String {
        battery.isCharging
            ? String(localized: "carregando")
            : battery.isPluggedIn ? String(localized: "na tomada") : String(localized: "na bateria")
    }

    /// "80%" ou, com o sensor, "80% · 31 °C".
    static func text(_ battery: BatteryStatus, temperature: String?) -> String {
        let percent = "\(battery.percent)%"
        return temperature.map { "\(percent) · \($0)" } ?? percent
    }

    /// Símbolo da bateria na carga mais próxima, ou com o raio enquanto carrega.
    static func symbol(_ battery: BatteryStatus) -> String {
        if battery.isCharging { return "battery.100percent.bolt" }
        return switch battery.percent {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }

    static func help(_ battery: BatteryStatus, temperature: String?) -> String {
        let state = state(battery)
        return temperature == nil
            ? String(localized: "Carga da bateria, \(state)")
            : String(localized: "Carga e temperatura da bateria, \(state)")
    }

    /// Há o que mostrar no badge do tempo: autonomia (ou "calculando") na bateria, ou o tempo para carregar.
    static func hasTime(_ battery: BatteryStatus) -> Bool {
        battery.isDischarging || battery.minutesToFull != nil
    }

    /// Texto e dica do badge do tempo; `nil` quando não há o que mostrar.
    static func time(_ battery: BatteryStatus, runtime: RuntimeEstimate?) -> (text: String, help: String)? {
        if battery.isDischarging { return runtimeContent(runtime) }
        if let minutes = battery.minutesToFull {
            return (
                String(localized: "Cheia em \(format(minutes: minutes))"),
                String(localized: "Tempo para completar a carga, estimado pelo macOS")
            )
        }
        return nil
    }

    private static func runtimeContent(_ runtime: RuntimeEstimate?) -> (text: String, help: String) {
        guard let runtime else {
            return (
                String(localized: "Calculando…"),
                String(localized: "A autonomia aparece depois de alguns minutos de medição na bateria")
            )
        }
        let text =
            runtime.exceedsDisplayLimit
            ? String(localized: "mais de 24 h") : "~" + format(minutes: runtime.roundedMinutes)
        let minutes = Int((runtime.basis / 60).rounded())
        return (
            text,
            String(
                localized:
                    "Autonomia no ritmo dos últimos \(minutes) min (\(runtime.watts.formatted(.watts))). Muda conforme o que você faz."
            )
        )
    }

    /// "1h 20min", "45min".
    static func format(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
