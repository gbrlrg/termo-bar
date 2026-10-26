import SwiftUI

/// Qual badge do cabeçalho está aberto.
enum BadgeKind: Hashable {
    case pressure, fan, battery
}

/// Pílula do cabeçalho que abre os detalhes ao clicar; a seta mostra que ela é um botão.
struct BadgeButton<Label: View>: View {
    let isExpanded: Bool
    /// Cor do texto e do fundo; sem ela, o badge é cinza.
    var tint: Color?
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                label
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .opacity(0.6)
            }
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint ?? .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
    }

    private var background: AnyShapeStyle {
        guard let tint else {
            return isExpanded ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.tertiary)
        }
        return AnyShapeStyle(tint.opacity(isExpanded ? 0.24 : 0.14))
    }
}

/// Linhas de detalhe de um badge, no mesmo estilo dos cards do popover.
struct BadgeDetailCard: View {
    let rows: [Row]
    var note: String?

    struct Row: Identifiable {
        let title: LocalizedStringKey
        let value: String
        var id: String { "\(title)" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.title).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(row.value).fontWeight(.medium).monospacedDigit()
                }
                .font(.callout)
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Conteúdo de cada badge

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

enum BadgeDetails {
    private static func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    static func pressure(_ pressure: ThermalPressure, samples: [Sample]) -> BadgeDetailCard {
        var rows = [BadgeDetailCard.Row(title: "Estado", value: pressure.label)]
        if let share = samples.throttledShare {
            rows.append(.init(title: "Limitado no período", value: percent(share)))
        }
        return BadgeDetailCard(rows: rows, note: pressure.explanation)
    }

    static func fan(rpm: Double, samples: [Sample]) -> BadgeDetailCard {
        var rows = [
            BadgeDetailCard.Row(
                title: "Rotação agora",
                value: rpm >= Fan.spinningThreshold ? rpm.formatted(.rpm) : String(localized: "Parado"))
        ]
        if let peak = samples.peakFanSpeed, peak >= Fan.spinningThreshold {
            rows.append(.init(title: "Pico no período", value: peak.formatted(.rpm)))
        }
        if let share = samples.fanSpinningShare {
            rows.append(.init(title: "Girando no período", value: percent(share)))
        }
        return BadgeDetailCard(rows: rows)
    }

    static func battery(_ battery: BatteryStatus, temperature: String?) -> BadgeDetailCard {
        let state =
            battery.isCharging
            ? String(localized: "carregando")
            : battery.isPluggedIn ? String(localized: "na tomada") : String(localized: "na bateria")
        var rows = [BadgeDetailCard.Row(title: "Carga", value: "\(battery.percent)% · \(state)")]
        if let health = battery.health {
            rows.append(.init(title: "Capacidade máxima", value: percent(health)))
        }
        if let cycles = battery.cycleCount {
            let value =
                battery.designCycleCount.map { String(localized: "\(cycles) de \($0)") }
                ?? cycles.formatted()
            rows.append(.init(title: "Ciclos", value: value))
        }
        if battery.isDischarging, let watts = battery.dischargeWatts {
            rows.append(.init(title: "Consumo do Mac", value: watts.formatted(.watts)))
        }
        if let temperature {
            rows.append(.init(title: "Temperatura", value: temperature))
        }
        return BadgeDetailCard(
            rows: rows,
            note: battery.health == nil
                ? nil : String(localized: "A capacidade máxima é a mesma dos Ajustes do Sistema."))
    }
}
