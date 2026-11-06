import Foundation

/// Uma linha de detalhe de um badge: título (já traduzido) e valor.
struct BadgeDetailRow: Equatable, Identifiable, Sendable {
    let title: String
    let value: String
    var id: String { title }
}

/// O que o card de detalhes de um badge mostra.
struct BadgeDetailContent: Equatable, Sendable {
    let rows: [BadgeDetailRow]
    var note: String?
}

extension ThermalPressure {
    /// O que o nível significa para quem não conhece os termos do kernel.
    var explanation: String {
        switch self {
        case .nominal: String(localized: "O chip trabalha na velocidade máxima, sem limitação.")
        case .moderate: String(localized: "O Mac está esquentando, mas o macOS ainda não reduz o desempenho.")
        case .heavy: String(localized: "O macOS está reduzindo a velocidade do chip para esfriar.")
        case .critical: String(localized: "O calor está alto: o macOS reduz bastante a velocidade do chip.")
        case .sleeping: String(localized: "O macOS pausou o trabalho do chip para esfriar.")
        }
    }
}

/// Conteúdo de cada badge do cabeçalho (estado térmico, ventoinha e bateria).
enum BadgeDetails {
    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func pressure(_ pressure: ThermalPressure, samples: [Sample]) -> BadgeDetailContent {
        var rows = [BadgeDetailRow(title: String(localized: "Estado"), value: pressure.label)]
        if let share = samples.throttledShare {
            rows.append(.init(title: String(localized: "Limitado no período"), value: percent(share)))
        }
        return BadgeDetailContent(rows: rows, note: pressure.explanation)
    }

    static func fan(rpm: Double, samples: [Sample]) -> BadgeDetailContent {
        var rows = [
            BadgeDetailRow(
                title: String(localized: "Rotação agora"),
                value: rpm >= Fan.spinningThreshold ? rpm.formatted(.rpm) : String(localized: "Parado"))
        ]
        if let peak = samples.peakFanSpeed, peak >= Fan.spinningThreshold {
            rows.append(.init(title: String(localized: "Pico no período"), value: peak.formatted(.rpm)))
        }
        if let share = samples.fanSpinningShare {
            rows.append(.init(title: String(localized: "Girando no período"), value: percent(share)))
        }
        return BadgeDetailContent(rows: rows)
    }

    static func battery(_ battery: BatteryStatus, temperature: String?) -> BadgeDetailContent {
        let state = BatteryBadgeContent.state(battery)
        var rows = [BadgeDetailRow(title: String(localized: "Carga"), value: "\(battery.percent)% · \(state)")]
        if let health = battery.health {
            rows.append(.init(title: String(localized: "Capacidade máxima"), value: percent(health)))
        }
        if let cycles = battery.cycleCount {
            let value =
                battery.designCycleCount.map { String(localized: "\(cycles) de \($0)") }
                ?? cycles.formatted()
            rows.append(.init(title: String(localized: "Ciclos"), value: value))
        }
        if battery.isDischarging, let watts = battery.dischargeWatts {
            rows.append(.init(title: String(localized: "Consumo do Mac"), value: watts.formatted(.watts)))
        }
        if let temperature {
            rows.append(.init(title: String(localized: "Temperatura"), value: temperature))
        }
        return BadgeDetailContent(
            rows: rows,
            note: battery.health == nil
                ? nil : String(localized: "A capacidade máxima é a mesma dos Ajustes do Sistema."))
    }
}
