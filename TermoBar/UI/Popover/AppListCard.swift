import SwiftUI

/// Ranking dos apps que mais gastaram no período.
struct AppListCard: View {
    let summary: RangeSummary
    @Binding var hoveredApp: String?
    @Binding var pinnedApp: String?

    @State private var isExpanded = false
    private let collapsedCount = 5

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(title: "Apps que mais aquecem", detail: "energia no período")
                VStack(spacing: 2) {
                    ForEach(isExpanded ? summary.rows : Array(summary.rows.prefix(collapsedCount))) { row in
                        AppRowView(summary: summary, row: row, isHighlighted: (pinnedApp ?? hoveredApp) == row.id)
                            .onHover { inside in
                                if inside {
                                    hoveredApp = row.id
                                } else if hoveredApp == row.id {
                                    hoveredApp = nil
                                }
                            }
                            .onTapGesture { pinnedApp = pinnedApp == row.id ? nil : row.id }
                    }
                }
                if summary.rows.count > collapsedCount {
                    expandButton
                }
                Text(
                    "Inclui os processos que cada app abre e a GPU de todos. A CPU de processos do sistema não entra na conta."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(.smooth) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Mostrar menos" : "Mostrar todos os \(summary.rows.count) apps")
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }
}

private struct AppRowView: View {
    @Environment(Monitor.self) private var monitor
    let summary: RangeSummary
    let row: AppRow
    let isHighlighted: Bool

    /// Abaixo desta fatia da energia o app aparece como ocioso.
    private static let idleShare = 0.005
    /// A partir desta potência média de GPU (W) o app ganha a etiqueta "GPU".
    private static let gpuBadgeWatts = 0.05

    var body: some View {
        HStack(spacing: 10) {
            AppIcon(id: row.id)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(row.name)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    usage
                }
                .monospacedDigit()
                HeatStrip(
                    row: row, summary: summary,
                    tint: monitor.palette[row.id].map { Theme.seriesColor(slot: $0) } ?? .secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            isHighlighted ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
        )
        .contentShape(Rectangle())
        .help(
            "CPU \(row.average.cpu.formatted(.watts)) · GPU \(row.average.gpu.formatted(.watts)) em média. Clique para destacar no gráfico."
        )
    }

    @ViewBuilder
    private var usage: some View {
        if row.share >= Self.idleShare {
            if row.average.gpu >= Self.gpuBadgeWatts {
                Text("GPU")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            Text(row.average.total.formatted(.watts))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(row.share.formatted(.percent.precision(.fractionLength(0))))
                .font(.callout.weight(.semibold))
                .frame(minWidth: 34, alignment: .trailing)
        } else {
            Text("ocioso").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

/// Linha do tempo do app: aberto (trilho) e consumo (cor mais forte = mais watts).
private struct HeatStrip: View {
    let row: AppRow
    let summary: RangeSummary
    let tint: Color

    /// Consumo abaixo disso (W) não pinta a faixa.
    private static let minimumWatts = 0.02

    var body: some View {
        Canvas { context, size in
            let span = summary.end.timeIntervalSince(summary.start)
            func x(_ date: Date) -> CGFloat {
                CGFloat(min(max(date.timeIntervalSince(summary.start) / span, 0), 1)) * size.width
            }

            context.fill(Capsule().path(in: CGRect(origin: .zero, size: size)), with: .style(.fill.quaternary))
            for interval in row.openIntervals {
                let start = x(interval.lowerBound)
                let rect = CGRect(x: start, y: 0, width: max(x(interval.upperBound) - start, 1), height: size.height)
                context.fill(Capsule().path(in: rect), with: .style(.fill.tertiary))
            }
            for (start, watts) in row.heat where watts >= Self.minimumWatts {
                let strength = min(watts / summary.peakHeat, 1)
                let x0 = x(start)
                let x1 = x(start.addingTimeInterval(summary.binSize))
                let rect = CGRect(x: x0, y: 0, width: max(x1 - x0, 1.5), height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(tint.opacity(0.3 + 0.7 * strength)))
            }
        }
        .frame(height: 5)
        .clipShape(Capsule())
    }
}
